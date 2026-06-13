import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/models/tag.dart';
import 'package:melody_pdf/providers/tag_provider.dart';
import 'package:melody_pdf/services/tag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build a TagProvider backed by a fresh mock SharedPreferences.
Future<TagProvider> _buildProvider(Map<String, Object> initialValues) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return TagProvider(TagService(prefs));
}

void main() {
  group('TagProvider', () {
    test('starts with no tags when prefs are empty', () async {
      final provider = await _buildProvider({});
      expect(provider.tags, isEmpty);
      expect(provider.hasTags, isFalse);
    });

    test('createTag adds tag and notifies', () async {
      final provider = await _buildProvider({});
      await provider.createTag(name: 'Work', color: 0xFFE57373);
      expect(provider.tags, hasLength(1));
      expect(provider.tags.first.name, equals('Work'));
      expect(provider.tags.first.color, equals(0xFFE57373));
    });

    test('createTag with empty name throws ArgumentError', () async {
      final provider = await _buildProvider({});
      expect(
        () => provider.createTag(name: '   ', color: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createTag generates unique ids', () async {
      final provider = await _buildProvider({});
      final t1 = await provider.createTag(name: 'A', color: 0);
      final t2 = await provider.createTag(name: 'B', color: 0);
      expect(t1.id, isNot(equals(t2.id)));
    });

    test('updateTag modifies an existing tag', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'Old', color: 0xFF0000);
      await provider.updateTag(tag.copyWith(name: 'New', color: 0x00FF00));
      expect(provider.tags.first.name, equals('New'));
      expect(provider.tags.first.color, equals(0x00FF00));
    });

    test('updateTag does nothing for unknown id', () async {
      final provider = await _buildProvider({});
      await provider.createTag(name: 'Only', color: 0);
      // Create a fake tag with an unknown id
      await provider.updateTag(Tag(id: 'unknown_id', name: 'X', color: 1));
      expect(provider.tags, hasLength(1));
      expect(provider.tags.first.name, equals('Only'));
    });

    test('deleteTag removes tag', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'ToDelete', color: 0);
      expect(provider.tags, hasLength(1));

      await provider.deleteTag(tag.id);
      expect(provider.tags, isEmpty);
    });

    test('deleteTag clears active filter if it matches deleted tag', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'FilterMe', color: 0);
      provider.setActiveFilter(tag.id);
      expect(provider.activeFilterTagId, equals(tag.id));

      await provider.deleteTag(tag.id);
      expect(provider.activeFilterTagId, isNull);
    });

    test('deleteTag is idempotent (no-op for unknown id)', () async {
      final provider = await _buildProvider({});
      await provider.createTag(name: 'Only', color: 0);
      // Should not throw
      await provider.deleteTag('nonexistent_id');
      expect(provider.tags, hasLength(1));
    });

    test('setActiveFilter and clearFilter work', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'F', color: 0);

      provider.setActiveFilter(tag.id);
      expect(provider.activeFilterTagId, equals(tag.id));
      expect(provider.activeFilterTag?.name, equals('F'));

      provider.clearFilter();
      expect(provider.activeFilterTagId, isNull);
    });

    test('setActiveFilter is a no-op when same id is set again', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'A', color: 0);
      provider.setActiveFilter(tag.id);
      // Setting same filter again should not throw (internal guard)
      provider.setActiveFilter(tag.id);
      expect(provider.activeFilterTagId, equals(tag.id));
    });

    test('tags getter returns unmodifiable list', () async {
      final provider = await _buildProvider({});
      await provider.createTag(name: 'A', color: 0);
      final list = provider.tags;
      expect(() => list.add(Tag(id: 'x', name: 'x', color: 0)), throwsA(isA<UnsupportedError>()));
    });

    // --- File ↔ tag mapping ---

    test('getTagsForFile returns empty list when no mapping', () async {
      final provider = await _buildProvider({});
      expect(provider.getTagsForFile('/any/file.pdf'), isEmpty);
    });

    test('setFileTags creates and retrieves mapping', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'T', color: 0);
      await provider.setFileTags('/doc.pdf', [tag.id]);
      expect(provider.getTagsForFile('/doc.pdf'), equals([tag.id]));
    });

    test('setFileTags with empty list removes mapping', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'T', color: 0);
      await provider.setFileTags('/doc.pdf', [tag.id]);
      expect(provider.getTagsForFile('/doc.pdf'), isNotEmpty);

      await provider.setFileTags('/doc.pdf', []);
      expect(provider.getTagsForFile('/doc.pdf'), isEmpty);
    });

    test('setFileTags deduplicates tag ids', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'T', color: 0);
      await provider.setFileTags('/doc.pdf', [tag.id, tag.id]);
      expect(provider.getTagsForFile('/doc.pdf'), hasLength(1));
    });

    test('toggleFileTag adds and removes a tag', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'T', color: 0);

      // Initially absent
      expect(provider.fileHasTag('/doc.pdf', tag.id), isFalse);

      await provider.toggleFileTag('/doc.pdf', tag.id);
      expect(provider.fileHasTag('/doc.pdf', tag.id), isTrue);

      await provider.toggleFileTag('/doc.pdf', tag.id);
      expect(provider.fileHasTag('/doc.pdf', tag.id), isFalse);
    });

    test('getResolvedTagsForFile returns Tag objects for mapped ids', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'Work', color: 0xFF0000);
      await provider.setFileTags('/doc.pdf', [tag.id]);

      final resolved = provider.getResolvedTagsForFile('/doc.pdf');
      expect(resolved, hasLength(1));
      expect(resolved.first.name, equals('Work'));
    });

    test('getResolvedTagsForFile filters out unknown tag ids', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'Real', color: 0);
      // Directly set an unknown id via a fresh provider that already has a tag
      await provider.setFileTags('/doc.pdf', [tag.id, 'ghost_id']);
      final resolved = provider.getResolvedTagsForFile('/doc.pdf');
      expect(resolved, hasLength(1));
      expect(resolved.first.id, equals(tag.id));
    });

    test('forgetFile removes all associations for a file path', () async {
      final provider = await _buildProvider({});
      final t1 = await provider.createTag(name: 'A', color: 0);
      final t2 = await provider.createTag(name: 'B', color: 0);
      await provider.setFileTags('/doc.pdf', [t1.id, t2.id]);
      expect(provider.getTagsForFile('/doc.pdf'), hasLength(2));

      await provider.forgetFile('/doc.pdf');
      expect(provider.getTagsForFile('/doc.pdf'), isEmpty);
    });

    test('forgetFile on unknown path does nothing', () async {
      final provider = await _buildProvider({});
      // Should not throw
      await provider.forgetFile('/never/existed.pdf');
      expect(provider.tags, isEmpty);
    });

    test('countFilesWithTag counts correctly', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'Shared', color: 0);
      await provider.setFileTags('/a.pdf', [tag.id]);
      await provider.setFileTags('/b.pdf', [tag.id]);
      await provider.setFileTags('/c.pdf', []); // no tag

      expect(provider.countFilesWithTag(tag.id), equals(2));
    });

    test('tagById returns correct tag', () async {
      final provider = await _buildProvider({});
      final tag = await provider.createTag(name: 'FindMe', color: 0);
      expect(provider.tagById(tag.id)?.name, equals('FindMe'));
    });

    test('tagById returns null for unknown id', () async {
      final provider = await _buildProvider({});
      expect(provider.tagById('nonexistent'), isNull);
    });

    test('persists tags across provider recreation', () async {
      // First provider instance: create a tag
      SharedPreferences.setMockInitialValues({});
      final prefs1 = await SharedPreferences.getInstance();
      final provider1 = TagProvider(TagService(prefs1));
      await provider1.createTag(name: 'Persistent', color: 0xABCDEF);

      // Simulate app restart: same prefs singleton still has the data
      final service = TagService(prefs1);
      expect(service.getAllTags(), hasLength(1));
      expect(service.getAllTags().first.name, equals('Persistent'));
    });
  });
}
