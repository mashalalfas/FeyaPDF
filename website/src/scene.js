/* =====================================================================
   Freya PDF — Three.js Hero Scene
   Low-poly cel-shaded study desk, lamp as key light, tablet with PDF.
   Upgraded: dust motes, glow halo, paper stack, eraser, paperclip,
   plant sway, notebook page-turn, mood-based material swap.
   ===================================================================== */

import * as THREE from 'three';

/* ---------------- Color palette (matches CSS) ---------------- */
const PALETTE = {
  bg:        new THREE.Color('#E8DDC4'),
  bgDark:    new THREE.Color('#1A1814'),
  wood:      new THREE.Color('#8B6B3D'),
  woodDark:  new THREE.Color('#5C4523'),
  woodLight: new THREE.Color('#B89060'),
  paper:     new THREE.Color('#F0E5CC'),
  paperWarm: new THREE.Color('#E6D5A8'),
  paperCool: new THREE.Color('#E8DDC4'),
  brass:     new THREE.Color('#C4A962'),
  brassDark: new THREE.Color('#8A7340'),
  sage:      new THREE.Color('#7D8B6F'),
  rust:      new THREE.Color('#B85C38'),
  teal:      new THREE.Color('#2A5B5C'),
  ink:       new THREE.Color('#2C2416'),
  cream:     new THREE.Color('#E8D9B8'),
  highlight: new THREE.Color('#E8B4BC'),
  lamp:      new THREE.Color('#FFD08A'),
  lampGlow:  new THREE.Color('#FFE4B0'),
  shadow:    new THREE.Color('#2A1E10'),
  leaf:      new THREE.Color('#5A6B4F'),
  leafLight: new THREE.Color('#7B8A65'),
  pot:       new THREE.Color('#9C7250'),
  dust:      new THREE.Color('#FFF1C9'),
};

/* ---------------- Cel-shaded material ---------------- */
function celMaterial({ color, emissive = 0x000000, emissiveIntensity = 0, side = THREE.FrontSide } = {}) {
  return new THREE.MeshToonMaterial({
    color: color instanceof THREE.Color ? color : new THREE.Color(color),
    emissive: new THREE.Color(emissive),
    emissiveIntensity,
    side,
  });
}

/* ---------------- Simple geometry helpers ---------------- */
function box(w, h, d, mat) {
  return new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
}
function cyl(rt, rb, h, seg, mat) {
  return new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
}

/* ---------------- Procedural radial-gradient texture (lamp glow) ---------------- */
function makeGlowTexture(size = 256) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(size/2, size/2, 0, size/2, size/2, size/2);
  g.addColorStop(0,   'rgba(255, 220, 160, 1.0)');
  g.addColorStop(0.25,'rgba(255, 200, 130, 0.55)');
  g.addColorStop(0.5, 'rgba(255, 180, 110, 0.20)');
  g.addColorStop(1,   'rgba(255, 180, 110, 0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

/* ---------------- Soft disc (sphere) used for fake volumetric light cone ---------------- */
function makeLightConeTexture(size = 256) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(size/2, 0, 0, size/2, 0, size/2);
  g.addColorStop(0,   'rgba(255, 220, 160, 0.45)');
  g.addColorStop(0.5, 'rgba(255, 200, 130, 0.12)');
  g.addColorStop(1,   'rgba(255, 200, 130, 0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

/* =====================================================================
   GEOMETRY BUILDERS
   ===================================================================== */

/* ---------------- Build desk ---------------- */
function buildDesk() {
  const group = new THREE.Group();
  group.name = 'Desk';

  const wood = celMaterial({ color: PALETTE.wood });
  const woodDark = celMaterial({ color: PALETTE.woodDark });
  const woodLight = celMaterial({ color: PALETTE.woodLight });

  // Tabletop
  const top = box(5.2, 0.12, 3.4, wood);
  top.position.y = 0;
  top.castShadow = true;
  top.receiveShadow = true;
  group.add(top);

  // Wood grain stripes (subtle, darker)
  for (let i = 0; i < 7; i++) {
    const stripe = box(5.0, 0.005, 0.025, woodDark);
    stripe.position.set((Math.random()-0.5)*0.3, 0.062, -1.4 + i * 0.42);
    group.add(stripe);
  }
  // Light grain (highlights)
  for (let i = 0; i < 4; i++) {
    const stripe = box(5.0, 0.005, 0.018, woodLight);
    stripe.position.set((Math.random()-0.5)*0.4, 0.063, -1.2 + i * 0.7);
    group.add(stripe);
  }

  // Edge bevel — thin brass strip on the front edge
  const edge = box(5.2, 0.02, 0.02, celMaterial({ color: PALETTE.brassDark }));
  edge.position.set(0, 0.04, 1.7);
  group.add(edge);

  // 4 legs
  const legGeo = new THREE.BoxGeometry(0.16, 1.4, 0.16);
  const legPositions = [
    [ 2.4, -0.76,  1.5],
    [-2.4, -0.76,  1.5],
    [ 2.4, -0.76, -1.5],
    [-2.4, -0.76, -1.5],
  ];
  for (const [x, y, z] of legPositions) {
    const leg = new THREE.Mesh(legGeo, woodDark);
    leg.position.set(x, y, z);
    leg.castShadow = true;
    group.add(leg);
  }

  // Apron strip
  const apron = box(5.0, 0.18, 0.05, woodLight);
  apron.position.set(0, -0.16, 1.55);
  group.add(apron);
  const apron2 = apron.clone();
  apron2.position.set(0, -0.16, -1.55);
  group.add(apron2);

  // Cross brace between front legs
  const brace = box(4.6, 0.08, 0.06, woodDark);
  brace.position.set(0, -0.55, 1.5);
  group.add(brace);

  return group;
}

/* ---------------- Build notebook ---------------- */
function buildNotebook() {
  const g = new THREE.Group();
  g.name = 'Notebook';

  const cover = celMaterial({ color: PALETTE.teal });
  const page = celMaterial({ color: PALETTE.paper });
  const ribbon = celMaterial({ color: PALETTE.rust });

  // Cover
  const c = box(0.9, 0.06, 1.2, cover);
  c.position.y = 0.06;
  g.add(c);

  // Pages
  const p = box(0.86, 0.04, 1.15, page);
  p.position.y = 0.08;
  g.add(p);

  // Ribbon
  const r = box(0.06, 0.02, 0.7, ribbon);
  r.position.set(0.32, 0.1, 0.2);
  g.add(r);

  // Embossed line
  const emboss = box(0.7, 0.005, 0.02, celMaterial({ color: PALETTE.cream }));
  emboss.position.set(0, 0.095, -0.4);
  g.add(emboss);

  // Decorative monogram dot
  const monogram = new THREE.Mesh(
    new THREE.CircleGeometry(0.08, 16),
    celMaterial({ color: PALETTE.brass, emissive: PALETTE.brass, emissiveIntensity: 0.15 })
  );
  monogram.rotation.x = -Math.PI / 2;
  monogram.position.set(0, 0.094, 0.2);
  g.add(monogram);

  // Sub-group containing a flippable "page" that occasionally turns
  const pageGroup = new THREE.Group();
  pageGroup.name = 'PageGroup';
  const turnPage = box(0.78, 0.005, 1.10, page);
  turnPage.position.y = 0.092;
  pageGroup.add(turnPage);
  g.add(pageGroup);
  g.userData.pageGroup = pageGroup;

  return g;
}

/* ---------------- Build tablet ---------------- */
function buildTablet(pdfTexture) {
  const g = new THREE.Group();
  g.name = 'Tablet';

  const bezel = celMaterial({ color: PALETTE.ink });
  const screen = new THREE.MeshBasicMaterial({ map: pdfTexture });

  // Body
  const body = box(1.4, 0.04, 1.9, bezel);
  body.position.y = 0.08;
  g.add(body);

  // Screen
  const screenMesh = new THREE.Mesh(new THREE.PlaneGeometry(1.28, 1.76), screen);
  screenMesh.rotation.x = -Math.PI / 2;
  screenMesh.position.y = 0.101;
  g.add(screenMesh);

  // Bezel rim
  const rim = box(1.32, 0.005, 1.82, celMaterial({ color: PALETTE.brassDark }));
  rim.position.y = 0.103;
  g.add(rim);

  // Home button
  const home = new THREE.Mesh(
    new THREE.CircleGeometry(0.04, 16),
    celMaterial({ color: PALETTE.brass })
  );
  home.rotation.x = -Math.PI / 2;
  home.position.set(0, 0.1035, -0.85);
  g.add(home);

  // Top speaker slit
  const speaker = box(0.5, 0.003, 0.015, celMaterial({ color: PALETTE.ink }));
  speaker.position.set(0, 0.1035, 0.85);
  g.add(speaker);

  return g;
}

/* ---------------- Build tea cup with better steam ---------------- */
function buildTeaCup() {
  const g = new THREE.Group();
  g.name = 'TeaCup';

  const cup = celMaterial({ color: PALETTE.cream });
  const tea = celMaterial({ color: PALETTE.paperWarm });

  // Body
  const body = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.16, 0.32, 20, 1, true),
    cup
  );
  body.position.y = 0.18;
  g.add(body);

  // Bottom
  const bottom = new THREE.Mesh(
    new THREE.CylinderGeometry(0.16, 0.16, 0.02, 20),
    cup
  );
  bottom.position.y = 0.02;
  g.add(bottom);

  // Tea surface
  const liquid = new THREE.Mesh(
    new THREE.CircleGeometry(0.21, 20),
    tea
  );
  liquid.rotation.x = -Math.PI / 2;
  liquid.position.y = 0.34;
  g.add(liquid);

  // Handle
  const handle = new THREE.Mesh(
    new THREE.TorusGeometry(0.08, 0.022, 8, 14, Math.PI),
    cup
  );
  handle.position.set(0.22, 0.18, 0);
  handle.rotation.set(0, 0, Math.PI / 2);
  g.add(handle);

  // Saucer
  const s = new THREE.Mesh(
    new THREE.CylinderGeometry(0.32, 0.30, 0.03, 28),
    cup
  );
  s.position.y = 0.01;
  g.add(s);
  const sInner = new THREE.Mesh(
    new THREE.CylinderGeometry(0.20, 0.20, 0.005, 28),
    new THREE.MeshToonMaterial({ color: PALETTE.paperWarm })
  );
  sInner.position.y = 0.025;
  g.add(sInner);

  // Tea-bag string + tag (small detail)
  const string = new THREE.Mesh(
    new THREE.CylinderGeometry(0.002, 0.002, 0.18, 4),
    new THREE.MeshBasicMaterial({ color: 0xFFFFFF })
  );
  string.position.set(-0.05, 0.42, 0.0);
  g.add(string);
  const tag = box(0.04, 0.02, 0.06, celMaterial({ color: PALETTE.brass }));
  tag.position.set(-0.05, 0.33, 0.0);
  g.add(tag);

  // Steam — many small wisps, animated in update loop
  const steamGroup = new THREE.Group();
  steamGroup.name = 'Steam';
  const WISP_COUNT = 8;
  for (let i = 0; i < WISP_COUNT; i++) {
    const wisp = new THREE.Mesh(
      new THREE.SphereGeometry(0.035 + Math.random() * 0.025, 6, 6),
      new THREE.MeshBasicMaterial({
        color: PALETTE.dust,
        transparent: true,
        opacity: 0,
        depthWrite: false,
      })
    );
    wisp.userData.baseY = 0.40;
    wisp.userData.life = Math.random();      // 0..1 starting point in cycle
    wisp.userData.speed = 0.15 + Math.random() * 0.2;
    wisp.userData.phase = Math.random() * Math.PI * 2;
    wisp.userData.driftX = (Math.random() - 0.5) * 0.04;
    wisp.userData.driftZ = (Math.random() - 0.5) * 0.04;
    wisp.userData.scale = 0.5 + Math.random() * 0.5;
    steamGroup.add(wisp);
  }
  g.add(steamGroup);

  return g;
}

/* ---------------- Build highlighter markers ---------------- */
function buildHighlighters() {
  const g = new THREE.Group();
  g.name = 'Highlighters';

  const colors = [PALETTE.brass, PALETTE.rust, PALETTE.sage, PALETTE.teal];
  colors.forEach((c, i) => {
    const cap = new THREE.Mesh(
      new THREE.CylinderGeometry(0.045, 0.045, 0.10, 12),
      new THREE.MeshToonMaterial({ color: c })
    );
    cap.position.set(0, 0.07, 0);

    const body = new THREE.Mesh(
      new THREE.CylinderGeometry(0.04, 0.04, 0.18, 12),
      new THREE.MeshToonMaterial({ color: PALETTE.cream })
    );
    body.position.set(0, -0.04, 0);

    const tip = new THREE.Mesh(
      new THREE.ConeGeometry(0.04, 0.06, 12),
      new THREE.MeshToonMaterial({ color: PALETTE.ink })
    );
    tip.position.set(0, -0.16, 0);
    tip.rotation.x = Math.PI;

    const marker = new THREE.Group();
    marker.add(cap, body, tip);
    marker.rotation.z = Math.PI / 2;
    marker.position.set(1.6 + i * 0.02, 0.08, 0.4 - i * 0.18);
    g.add(marker);
  });

  return g;
}

/* ---------------- Build lamp with glow halo ---------------- */
function buildLamp() {
  const g = new THREE.Group();
  g.name = 'Lamp';

  const brass = celMaterial({ color: PALETTE.brass });
  const brassDark = celMaterial({ color: PALETTE.brassDark });
  const shade = celMaterial({
    color: PALETTE.lampGlow,
    emissive: PALETTE.lamp,
    emissiveIntensity: 0.45,
  });

  // Base
  const base = cyl(0.22, 0.26, 0.06, 18, brassDark);
  base.position.y = 0.08;
  g.add(base);
  // Small ridge on base
  const ridge = cyl(0.24, 0.24, 0.015, 18, brass);
  ridge.position.y = 0.115;
  g.add(ridge);

  // Stem
  const stem1 = cyl(0.025, 0.025, 0.5, 10, brass);
  stem1.position.set(0, 0.36, 0);
  g.add(stem1);

  const stem2 = cyl(0.022, 0.025, 0.4, 10, brass);
  stem2.position.set(0, 0.82, 0);
  g.add(stem2);

  // Joint between stem segments
  const joint = new THREE.Mesh(
    new THREE.SphereGeometry(0.035, 10, 8),
    brassDark
  );
  joint.position.set(0, 0.6, 0);
  g.add(joint);

  // Shade
  const shadeMesh = new THREE.Mesh(
    new THREE.ConeGeometry(0.32, 0.30, 20, 1, true),
    shade
  );
  shadeMesh.position.set(0, 1.18, 0);
  shadeMesh.rotation.x = Math.PI;
  g.add(shadeMesh);

  // Inner shade highlight (lighter color, slightly inset)
  const innerShade = new THREE.Mesh(
    new THREE.ConeGeometry(0.30, 0.28, 20, 1, true),
    celMaterial({
      color: PALETTE.lampGlow,
      emissive: PALETTE.lamp,
      emissiveIntensity: 0.8,
      side: THREE.BackSide,
    })
  );
  innerShade.position.set(0, 1.19, 0);
  innerShade.rotation.x = Math.PI;
  g.add(innerShade);

  // Bulb
  const bulb = new THREE.Mesh(
    new THREE.SphereGeometry(0.06, 12, 12),
    new THREE.MeshBasicMaterial({
      color: PALETTE.lamp,
      transparent: true,
      opacity: 0.95,
    })
  );
  bulb.position.set(0, 1.06, 0);
  bulb.name = 'Bulb';
  g.add(bulb);

  // Glow halo (billboard)
  const glowTex = makeGlowTexture(256);
  const glowMat = new THREE.SpriteMaterial({
    map: glowTex,
    color: 0xFFE0A8,
    transparent: true,
    opacity: 1,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  const glow = new THREE.Sprite(glowMat);
  glow.scale.set(1.4, 1.4, 1);
  glow.position.set(0, 1.06, 0);
  glow.name = 'Glow';
  g.add(glow);

  // Light cone below the shade (large additive disc)
  const coneTex = makeLightConeTexture(256);
  const coneMat = new THREE.MeshBasicMaterial({
    map: coneTex,
    color: 0xFFE0A8,
    transparent: true,
    opacity: 0.35,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    side: THREE.DoubleSide,
  });
  const cone = new THREE.Mesh(
    new THREE.PlaneGeometry(2.4, 2.0),
    coneMat
  );
  cone.position.set(0, 0.2, 0);
  cone.rotation.x = -Math.PI / 2;
  cone.name = 'LightCone';
  g.add(cone);

  // Knob on top
  const knob = new THREE.Mesh(
    new THREE.SphereGeometry(0.04, 10, 8),
    brass
  );
  knob.position.set(0, 1.36, 0);
  g.add(knob);

  // Pull-chain (tiny detail)
  const chain = new THREE.Mesh(
    new THREE.CylinderGeometry(0.004, 0.004, 0.10, 4),
    new THREE.MeshBasicMaterial({ color: 0xC9A24A })
  );
  chain.position.set(0.20, 1.0, 0.0);
  g.add(chain);
  const chainBead = new THREE.Mesh(
    new THREE.SphereGeometry(0.012, 6, 6),
    new THREE.MeshBasicMaterial({ color: 0x8A7340 })
  );
  chainBead.position.set(0.20, 0.94, 0.0);
  g.add(chainBead);

  return g;
}

/* ---------------- Build small plant with sway ---------------- */
function buildPlant() {
  const g = new THREE.Group();
  g.name = 'Plant';

  const potMat = celMaterial({ color: PALETTE.pot });
  const leafMat = celMaterial({ color: PALETTE.leaf });
  const leafLight = celMaterial({ color: PALETTE.leafLight });

  // Pot
  const pot = new THREE.Mesh(
    new THREE.CylinderGeometry(0.18, 0.14, 0.28, 14),
    potMat
  );
  pot.position.y = 0.14;
  g.add(pot);

  // Pot rim
  const rim = new THREE.Mesh(
    new THREE.CylinderGeometry(0.185, 0.185, 0.02, 14),
    celMaterial({ color: PALETTE.woodLight })
  );
  rim.position.y = 0.27;
  g.add(rim);

  // Soil
  const soil = new THREE.Mesh(
    new THREE.CircleGeometry(0.17, 14),
    new THREE.MeshToonMaterial({ color: PALETTE.woodDark })
  );
  soil.rotation.x = -Math.PI / 2;
  soil.position.y = 0.28;
  g.add(soil);

  // Leaves (low-poly cones in a "leaves" group that sways)
  const leavesGroup = new THREE.Group();
  leavesGroup.name = 'Leaves';
  const leafShapes = [
    { x:  0.00, z:  0.00, ry: 0.30, rz: 0.0,  mat: leafMat },
    { x:  0.10, z:  0.05, ry: 0.50, rz: 0.4,  mat: leafLight },
    { x: -0.08, z:  0.08, ry: 0.40, rz: -0.3, mat: leafMat },
    { x:  0.05, z: -0.10, ry: 0.55, rz: 0.2,  mat: leafLight },
    { x: -0.10, z: -0.04, ry: 0.45, rz: -0.4, mat: leafMat },
    { x:  0.12, z: -0.04, ry: 0.35, rz: 0.5,  mat: leafMat },
  ];
  for (const l of leafShapes) {
    const leaf = new THREE.Mesh(
      new THREE.ConeGeometry(0.05, l.ry, 5),
      l.mat
    );
    leaf.position.set(l.x, 0.28 + l.ry / 2, l.z);
    leaf.rotation.z = l.rz;
    leavesGroup.add(leaf);
  }
  g.add(leavesGroup);
  g.userData.leavesGroup = leavesGroup;

  return g;
}

/* ---------------- Build pencil ---------------- */
function buildPencil() {
  const g = new THREE.Group();
  g.name = 'Pencil';

  const shaft = celMaterial({ color: PALETTE.brass });
  const tipWood = celMaterial({ color: PALETTE.paperWarm });
  const tipLead = celMaterial({ color: PALETTE.ink });
  const eraser = celMaterial({ color: PALETTE.rust });

  const shaftMesh = new THREE.Mesh(
    new THREE.CylinderGeometry(0.025, 0.025, 0.7, 8),
    shaft
  );
  g.add(shaftMesh);

  const woodTip = new THREE.Mesh(
    new THREE.ConeGeometry(0.025, 0.05, 8),
    tipWood
  );
  woodTip.position.y = 0.375;
  woodTip.rotation.x = Math.PI;
  g.add(woodTip);

  const leadTip = new THREE.Mesh(
    new THREE.ConeGeometry(0.008, 0.02, 6),
    tipLead
  );
  leadTip.position.y = 0.41;
  leadTip.rotation.x = Math.PI;
  g.add(leadTip);

  const eraserMesh = new THREE.Mesh(
    new THREE.CylinderGeometry(0.028, 0.028, 0.05, 8),
    eraser
  );
  eraserMesh.position.y = -0.375;
  g.add(eraserMesh);

  const ferrule = new THREE.Mesh(
    new THREE.CylinderGeometry(0.028, 0.028, 0.04, 8),
    celMaterial({ color: PALETTE.brassDark })
  );
  ferrule.position.y = -0.33;
  g.add(ferrule);

  g.rotation.z = Math.PI / 2;
  g.position.y = 0.06;
  return g;
}

/* ---------------- Build book stack ---------------- */
function buildBookStack() {
  const g = new THREE.Group();
  g.name = 'BookStack';

  const colors = [PALETTE.rust, PALETTE.sage, PALETTE.brass];
  colors.forEach((c, i) => {
    const book = box(0.7, 0.08, 0.5, celMaterial({ color: c }));
    book.position.y = 0.05 + i * 0.085;
    g.add(book);

    const pages = box(0.66, 0.07, 0.46, celMaterial({ color: PALETTE.paper }));
    pages.position.y = 0.05 + i * 0.085;
    g.add(pages);

    // Tiny title bar on spine
    const spine = box(0.66, 0.04, 0.005, celMaterial({ color: PALETTE.brassDark }));
    spine.position.set(0, 0.05 + i * 0.085, 0.252);
    g.add(spine);
  });

  return g;
}

/* ---------------- Build a stack of loose papers ---------------- */
function buildPaperStack() {
  const g = new THREE.Group();
  g.name = 'PaperStack';

  // Slightly skewed pile of paper sheets
  for (let i = 0; i < 5; i++) {
    const sheet = box(0.7, 0.008, 0.5, celMaterial({ color: i % 2 ? PALETTE.paper : PALETTE.paperWarm }));
    sheet.position.set((Math.random() - 0.5) * 0.04, 0.005 + i * 0.012, (Math.random() - 0.5) * 0.04);
    sheet.rotation.y = (Math.random() - 0.5) * 0.18;
    g.add(sheet);
  }

  // Hand-written lines on top sheet (subtle)
  for (let i = 0; i < 4; i++) {
    const line = box(0.4, 0.001, 0.012, celMaterial({ color: PALETTE.ink }));
    line.position.set(-0.05, 0.07, -0.1 + i * 0.05);
    line.rotation.y = (Math.random() - 0.5) * 0.1;
    g.add(line);
  }

  return g;
}

/* ---------------- Build eraser block ---------------- */
function buildEraser() {
  const g = new THREE.Group();
  g.name = 'Eraser';

  const body = box(0.16, 0.06, 0.08, celMaterial({ color: PALETTE.rust }));
  body.position.y = 0.03;
  g.add(body);

  // Sleeve
  const sleeve = box(0.17, 0.02, 0.09, celMaterial({ color: PALETTE.cream }));
  sleeve.position.y = 0.06;
  g.add(sleeve);

  return g;
}

/* ---------------- Build a paperclip ---------------- */
function buildPaperclip() {
  const g = new THREE.Group();
  g.name = 'Paperclip';

  const mat = new THREE.MeshStandardMaterial({
    color: 0xC0C0C0,
    metalness: 0.6,
    roughness: 0.4,
    emissive: 0x444444,
    emissiveIntensity: 0.05,
  });

  // Build a stylized paperclip with a tube
  const pts = [
    new THREE.Vector3(-0.06, 0,  0.02),
    new THREE.Vector3(-0.06, 0, -0.02),
    new THREE.Vector3( 0.04, 0, -0.02),
    new THREE.Vector3( 0.04, 0,  0.02),
    new THREE.Vector3(-0.04, 0,  0.02),
    new THREE.Vector3(-0.04, 0, -0.005),
  ];
  const curve = new THREE.CatmullRomCurve3(pts, false, true, 0.0);
  const tubeGeo = new THREE.TubeGeometry(curve, 32, 0.006, 6, false);
  const tube = new THREE.Mesh(tubeGeo, mat);
  tube.rotation.x = Math.PI / 2;
  g.add(tube);

  g.rotation.set(-0.3, 0.4, 0.2);
  g.position.y = 0.012;
  return g;
}

/* ---------------- Build floating dust motes (atmospheric particles) ---------------- */
function buildDustMotes(count = 110) {
  const g = new THREE.Group();
  g.name = 'DustMotes';

  // Generate a tiny round texture procedurally
  const c = document.createElement('canvas');
  c.width = c.height = 32;
  const ctx = c.getContext('2d');
  const grad = ctx.createRadialGradient(16, 16, 0, 16, 16, 16);
  grad.addColorStop(0, 'rgba(255,240,200,1)');
  grad.addColorStop(0.5, 'rgba(255,240,200,0.3)');
  grad.addColorStop(1, 'rgba(255,240,200,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 32, 32);
  const tex = new THREE.CanvasTexture(c);

  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const basePos = new Float32Array(count * 3);
  const seeds = new Float32Array(count * 3); // phase, speed, amp

  for (let i = 0; i < count; i++) {
    const x = (Math.random() - 0.5) * 6;
    const y = Math.random() * 3.0;        // 0..3
    const z = (Math.random() - 0.5) * 3.5;
    positions[i*3+0] = x; basePos[i*3+0] = x;
    positions[i*3+1] = y; basePos[i*3+1] = y;
    positions[i*3+2] = z; basePos[i*3+2] = z;
    seeds[i*3+0] = Math.random() * Math.PI * 2;        // phase
    seeds[i*3+1] = 0.05 + Math.random() * 0.12;       // speed
    seeds[i*3+2] = 0.05 + Math.random() * 0.12;       // amp
  }

  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geo.setAttribute('aBase',    new THREE.BufferAttribute(basePos, 3));
  geo.setAttribute('aSeed',    new THREE.BufferAttribute(seeds, 3));

  const mat = new THREE.PointsMaterial({
    map: tex,
    color: 0xFFE9B8,
    size: 0.045,
    transparent: true,
    opacity: 0.65,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    sizeAttenuation: true,
  });

  const points = new THREE.Points(geo, mat);
  g.add(points);
  g.userData.points = points;
  return g;
}

/* =====================================================================
   PDF CanvasTexture — drawn dynamically on the tablet screen.
   ===================================================================== */
class PDFTexture {
  constructor(width = 512, height = 768) {
    this.canvas = document.createElement('canvas');
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext('2d');
    this.texture = new THREE.CanvasTexture(this.canvas);
    this.texture.colorSpace = THREE.SRGBColorSpace;
    this.texture.anisotropy = 4;
    this.width = width;
    this.height = height;
    this.time = 0;
    this.draw(0);
  }
  draw(t) {
    const { ctx, width: w, height: h } = this;
    // Paper background with warm gradient
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#F7EFD9');
    grad.addColorStop(1, '#EBDFC1');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    // Subtle texture dots
    ctx.fillStyle = 'rgba(44,36,22,0.025)';
    for (let i = 0; i < 80; i++) {
      const x = (i * 37) % w;
      const y = (i * 53) % h;
      ctx.fillRect(x, y, 1, 1);
    }

    // Margin line
    ctx.strokeStyle = 'rgba(184, 92, 56, 0.4)';
    ctx.lineWidth = 0.6;
    ctx.beginPath();
    ctx.moveTo(56, 0);
    ctx.lineTo(56, h);
    ctx.stroke();

    // Header
    ctx.fillStyle = '#2C2416';
    ctx.font = 'bold 18px serif';
    ctx.textBaseline = 'top';
    ctx.fillText('Chapter II — On Careful Reading', 72, 32);

    // Underline
    ctx.strokeStyle = '#7D8B6F';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(72, 60);
    ctx.lineTo(260, 60);
    ctx.stroke();

    // Body text — animated "reading" progress
    ctx.fillStyle = '#4A3F2A';
    ctx.font = '13px serif';
    const lineHeight = 18;
    const startY = 80;
    const lineWidths = [0.92, 0.88, 0.95, 0.75, 0.90, 0.85, 0.93, 0.80, 0.95, 0.70,
                        0.90, 0.86, 0.92, 0.78, 0.95, 0.88, 0.93, 0.82, 0.90, 0.85,
                        0.95, 0.80, 0.92, 0.88, 0.94, 0.75, 0.90, 0.85, 0.93, 0.80];
    for (let i = 0; i < 30; i++) {
      const y = startY + i * lineHeight;
      if (y > h - 80) break;
      const lw = (w - 100) * lineWidths[i];
      const progress = Math.min(1, Math.max(0, (t * 0.6 - i * 0.04)));
      const drawnWidth = lw * progress;
      if (drawnWidth > 0) {
        ctx.fillStyle = '#4A3F2A';
        ctx.fillRect(72, y, drawnWidth, 6);
      }
    }

    // Highlight on one line
    if (t > 0.4) {
      const hy = startY + 6 * lineHeight - 3;
      ctx.fillStyle = 'rgba(232, 180, 188, 0.6)';
      ctx.fillRect(70, hy, (w - 100) * 0.85, 12);
      ctx.fillStyle = '#2C2416';
      ctx.fillRect(72, hy + 2, (w - 100) * 0.85, 6);
    }

    // Margin note (rotated)
    ctx.save();
    ctx.fillStyle = 'rgba(184, 92, 56, 0.85)';
    ctx.font = 'italic 14px "Caveat", "Comic Sans MS", cursive';
    ctx.translate(20, 0);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText('a quiet place to think', -h + 60, 0);
    ctx.restore();

    // Page number
    ctx.fillStyle = '#6B5F47';
    ctx.font = '11px serif';
    ctx.textAlign = 'center';
    ctx.fillText('— 14 —', w / 2, h - 32);
    ctx.textAlign = 'left';

    this.texture.needsUpdate = true;
  }
  update(dt) {
    this.time += dt;
    this.draw(this.time);
  }
}

/* =====================================================================
   Main scene class
   ===================================================================== */
export class DeskScene {
  constructor(canvas) {
    this.canvas = canvas;
    this.mouse = { x: 0, y: 0, tx: 0, ty: 0 };
    this.touch = { x: 0, y: 0, active: false };
    this.target = { x: 0, y: 0, z: 0 };
    this.idleAngle = 0;
    this.lampIntensity = 1.0;
    this.targetLampIntensity = 1.0;
    this.scrollProgress = 0;
    this.litAt = 0;
    this.flickerPhase = 0;
    this._init();
    this._bindEvents();
    this._animate(0);
  }

  _init() {
    // Detect low-power / mobile → reduce particle counts
    this.isMobile = /Mobi|Android|iPhone|iPad/i.test(navigator.userAgent) ||
                    (window.innerWidth < 720);
    this.dustCount = this.isMobile ? 30 : 80;
    this.pixelRatio = Math.min(window.devicePixelRatio || 1, this.isMobile ? 1.5 : 2);

    // Renderer
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: !this.isMobile,
      alpha: true,
      powerPreference: this.isMobile ? 'default' : 'high-performance',
      stencil: false,
      depth: true,
    });
    this.renderer.setPixelRatio(this.pixelRatio);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.shadowMap.enabled = !this.isMobile;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    // Scene
    this.scene = new THREE.Scene();
    this.scene.background = null;
    this.scene.fog = new THREE.Fog(PALETTE.bg, 8, 22);

    // Camera
    this.camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
    this.cameraBase = new THREE.Vector3(0, 2.2, 5.6);
    this.camera.position.copy(this.cameraBase);
    this.camera.lookAt(0, 0.6, 0);

    // Lights
    this._setupLights();

    // PDF texture on tablet
    this.pdfTexture = new PDFTexture(512, 768);

    // Build scene
    this._buildScene();

    // Initial size
    this._resize();
  }

  _setupLights() {
    // Ambient
    this.ambient = new THREE.AmbientLight(PALETTE.bg, 0.25);
    this.scene.add(this.ambient);

    // Hemisphere
    this.hemi = new THREE.HemisphereLight(0xE8DDC4, 0x2A1E10, 0.35);
    this.scene.add(this.hemi);

    // Lamp point light
    this.lampPoint = new THREE.PointLight(PALETTE.lamp, 3.5, 8, 1.6);
    this.lampPoint.position.set(-1.6, 1.2, 0.3);
    this.lampPoint.castShadow = !this.isMobile;
    this.lampPoint.shadow.mapSize.set(1024, 1024);
    this.lampPoint.shadow.bias = -0.001;
    this.scene.add(this.lampPoint);

    // Lamp spot light
    this.lampSpot = new THREE.SpotLight(
      PALETTE.lamp,
      4.0,
      6,
      Math.PI / 4,
      0.5,
      1.5
    );
    this.lampSpot.position.set(-1.6, 1.05, 0.3);
    this.lampSpot.target.position.set(0.6, 0, 0.2);
    this.lampSpot.castShadow = !this.isMobile;
    this.lampSpot.shadow.mapSize.set(1024, 1024);
    this.lampSpot.shadow.bias = -0.001;
    this.scene.add(this.lampSpot);
    this.scene.add(this.lampSpot.target);

    // Rim light
    this.rim = new THREE.DirectionalLight(0xFFD9A8, 0.18);
    this.rim.position.set(3, 2, -2);
    this.scene.add(this.rim);

    // Subtle cool fill from below (simulates ambient bounce)
    this.fill = new THREE.DirectionalLight(0xC8B89A, 0.10);
    this.fill.position.set(-2, -1, 1);
    this.scene.add(this.fill);
  }

  _buildScene() {
    // Desk
    this.desk = buildDesk();
    this.scene.add(this.desk);

    // Floor
    const floorMat = new THREE.MeshToonMaterial({ color: PALETTE.bg });
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(20, 20), floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -1.5;
    floor.receiveShadow = !this.isMobile;
    this.scene.add(floor);

    // Back wall
    const wallMat = new THREE.MeshToonMaterial({ color: PALETTE.bg });
    const wall = new THREE.Mesh(new THREE.PlaneGeometry(20, 10), wallMat);
    wall.position.set(0, 1.5, -3);
    wall.receiveShadow = !this.isMobile;
    this.scene.add(wall);

    // Tablet
    this.tablet = buildTablet(this.pdfTexture.texture);
    this.tablet.position.set(0.4, 0.08, 0.2);
    this.tablet.rotation.y = -0.18;
    this.scene.add(this.tablet);

    // Notebook
    this.notebook = buildNotebook();
    this.notebook.position.set(-1.4, 0.08, -0.8);
    this.notebook.rotation.y = 0.3;
    this.scene.add(this.notebook);

    // Tea cup
    this.teaCup = buildTeaCup();
    this.teaCup.position.set(1.5, 0.08, 0.6);
    this.scene.add(this.teaCup);

    // Highlighters
    this.highlighters = buildHighlighters();
    this.highlighters.position.set(0.4, 0.07, 1.2);
    this.scene.add(this.highlighters);

    // Pencil
    this.pencil = buildPencil();
    this.pencil.position.set(-0.5, 0.08, 1.3);
    this.pencil.rotation.y = -0.6;
    this.scene.add(this.pencil);

    // Plant
    this.plant = buildPlant();
    this.plant.position.set(1.9, 0.08, -1.0);
    this.scene.add(this.plant);

    // Book stack
    this.books = buildBookStack();
    this.books.position.set(-1.9, 0.08, 0.4);
    this.books.rotation.y = 0.2;
    this.scene.add(this.books);

    // New: paper stack
    this.papers = buildPaperStack();
    this.papers.position.set(1.0, 0.08, -0.5);
    this.papers.rotation.y = -0.4;
    this.scene.add(this.papers);

    // New: eraser
    this.eraser = buildEraser();
    this.eraser.position.set(0.9, 0.08, 0.9);
    this.eraser.rotation.y = 0.5;
    this.scene.add(this.eraser);

    // New: paperclip
    this.paperclip = buildPaperclip();
    this.paperclip.position.set(-0.9, 0.08, 0.8);
    this.scene.add(this.paperclip);

    // Lamp
    this.lamp = buildLamp();
    this.lamp.position.set(-1.6, 0.08, -0.3);
    this.lamp.rotation.y = 0.4;
    this.scene.add(this.lamp);

    // Dust motes (atmosphere)
    this.dust = buildDustMotes(this.dustCount);
    this.dust.position.y = 0.4;
    this.scene.add(this.dust);
  }

  _bindEvents() {
    this._onResize = this._resize.bind(this);
    this._onMouseMove = this._onMouseMove.bind(this);
    this._onTouchMove = this._onTouchMove.bind(this);
    this._onTouchEnd = this._onTouchEnd.bind(this);
    window.addEventListener('resize', this._onResize, { passive: true });
    window.addEventListener('mousemove', this._onMouseMove, { passive: true });
    window.addEventListener('touchmove', this._onTouchMove, { passive: true });
    window.addEventListener('touchend', this._onTouchEnd, { passive: true });
  }

  _onMouseMove(e) {
    const nx = (e.clientX / window.innerWidth) * 2 - 1;
    const ny = (e.clientY / window.innerHeight) * 2 - 1;
    this.mouse.tx = nx;
    this.mouse.ty = ny;
  }

  _onTouchMove(e) {
    if (e.touches.length > 0) {
      const t = e.touches[0];
      this.touch.x = (t.clientX / window.innerWidth) * 2 - 1;
      this.touch.y = (t.clientY / window.innerHeight) * 2 - 1;
      this.touch.active = true;
      this.mouse.tx = this.touch.x;
      this.mouse.ty = this.touch.y;
    }
  }

  _onTouchEnd() {
    this.touch.active = false;
    // ease the mouse back to neutral
    this.mouse.tx = 0;
    this.mouse.ty = 0;
  }

  _resize() {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    if (!w || !h) return;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    // Camera distance tuning
    if (w < 480) {
      this.cameraBase.set(0, 2.5, 7.6);
    } else if (w < 720) {
      this.cameraBase.set(0, 2.4, 7.0);
    } else if (w < 900) {
      this.cameraBase.set(0, 2.3, 6.2);
    } else {
      this.cameraBase.set(0, 2.2, 5.6);
    }
    this.camera.updateProjectionMatrix();
  }

  setScrollProgress(p) {
    this.scrollProgress = Math.max(0, Math.min(1, p));
  }

  setMode(mode) {
    if (mode === 'dark') {
      this.scene.fog.color.set('#1A1814');
      this.ambient.color.set('#3A2E1E');
      this.ambient.intensity = 0.18;
      this.hemi.color.set('#3A2E1E');
      this.hemi.groundColor.set('#0A0805');
      this.lampPoint.color.set('#FFB060');
      this.lampSpot.color.set('#FFB060');
      this.rim.color.set('#FF9C5C');
      this.renderer.toneMappingExposure = 0.85;
    } else {
      this.scene.fog.color.set(PALETTE.bg);
      this.ambient.color.set(PALETTE.bg);
      this.ambient.intensity = 0.25;
      this.hemi.color.set(0xE8DDC4);
      this.hemi.groundColor.set(0x2A1E10);
      this.lampPoint.color.set(PALETTE.lamp);
      this.lampSpot.color.set(PALETTE.lamp);
      this.rim.color.set(0xFFD9A8);
      this.renderer.toneMappingExposure = 1.05;
    }
  }

  relightLamp() {
    this.litAt = performance.now();
  }

  _animate(t) {
    const ts = t / 1000;
    const dt = Math.min(0.05, ts - (this._lastT || ts));
    this._lastT = ts;

    // Mouse parallax smoothing
    this.mouse.x += (this.mouse.tx - this.mouse.x) * 0.08;
    this.mouse.y += (this.mouse.ty - this.mouse.y) * 0.08;

    // Idle orbit
    this.idleAngle += dt * 0.04;

    // Camera
    const orbitX = Math.sin(this.idleAngle) * 0.4;
    const orbitY = Math.cos(this.idleAngle * 0.7) * 0.05;
    const parallaxX = this.mouse.x * 0.5;
    const parallaxY = -this.mouse.y * 0.3;

    this.camera.position.x = this.cameraBase.x + orbitX + parallaxX;
    this.camera.position.y = this.cameraBase.y + orbitY + parallaxY;
    this.camera.position.z = this.cameraBase.z;

    // Zoom out + tilt as we scroll
    const zoomOut = 1 + this.scrollProgress * 0.6;
    this.camera.position.z = this.cameraBase.z * zoomOut;
    const tiltX = this.scrollProgress * 0.18;
    const liftY = this.scrollProgress * 0.4;
    this.camera.rotation.x = -tiltX;
    this.camera.position.y += liftY;
    this.camera.lookAt(0, 0.6 + this.scrollProgress * 0.3, 0);

    // Lamp intensity (relight pulse + gentle flicker)
    const sinceLit = (performance.now() - this.litAt) / 1000;
    this.flickerPhase += dt * 6.0;
    const flicker = 0.98 + Math.sin(this.flickerPhase * 1.3) * 0.015
                          + (Math.random() - 0.5) * 0.012;
    if (this.litAt > 0 && sinceLit < 2.5) {
      const k = sinceLit / 2.5;
      this.targetLampIntensity = 1.0 + Math.sin(k * Math.PI) * 1.4;
    } else {
      this.targetLampIntensity = 1.0;
    }
    this.lampIntensity += (this.targetLampIntensity - this.lampIntensity) * 0.1;

    this.lampPoint.intensity = 3.5 * this.lampIntensity * flicker;
    this.lampSpot.intensity  = 4.0 * this.lampIntensity * flicker;

    // Bulb + glow scale with intensity
    const bulb = this.lamp.getObjectByName('Bulb');
    if (bulb) {
      const s = 0.6 + this.lampIntensity * 0.6;
      bulb.scale.setScalar(s);
      bulb.material.opacity = Math.min(1, 0.5 + this.lampIntensity * 0.5);
    }
    const glow = this.lamp.getObjectByName('Glow');
    if (glow) {
      const gs = (0.8 + this.lampIntensity * 0.6) * (0.95 + Math.sin(this.flickerPhase * 1.7) * 0.05);
      glow.scale.set(gs * 1.4, gs * 1.4, 1);
      glow.material.opacity = Math.min(1, 0.55 + this.lampIntensity * 0.45);
    }
    const cone = this.lamp.getObjectByName('LightCone');
    if (cone) {
      cone.material.opacity = 0.25 + this.lampIntensity * 0.15;
    }

    // PDF texture
    this.pdfTexture.update(dt);

    // Tea steam — multi-wisp looping
    if (this.teaCup) {
      const steam = this.teaCup.getObjectByName('Steam');
      if (steam) {
        steam.children.forEach((wisp) => {
          // Each wisp has a life 0..1 that loops
          wisp.userData.life += dt * wisp.userData.speed;
          if (wisp.userData.life > 1) wisp.userData.life = 0;

          const life = wisp.userData.life;
          const y = wisp.userData.baseY + life * 0.55;
          const wob = Math.sin(life * Math.PI * 2 + wisp.userData.phase) * 0.05;
          wisp.position.y = y;
          wisp.position.x = wob * wisp.userData.driftX * 4;
          wisp.position.z = wob * wisp.userData.driftZ * 4;

          // Fade in → out across the cycle
          const fade = Math.sin(life * Math.PI); // 0 → 1 → 0
          wisp.material.opacity = 0.35 * fade * wisp.userData.scale;
          const sc = wisp.userData.scale * (0.7 + life * 0.8);
          wisp.scale.setScalar(sc);
        });
      }
    }

    // Plant sway (subtle)
    if (this.plant && this.plant.userData.leavesGroup) {
      const lg = this.plant.userData.leavesGroup;
      const sw = Math.sin(ts * 0.7) * 0.03 + Math.sin(ts * 1.3) * 0.01;
      lg.rotation.z = sw;
      lg.rotation.x = Math.cos(ts * 0.5) * 0.015;
    }

    // Notebook page turn (occasional, subtle)
    if (this.notebook && this.notebook.userData.pageGroup) {
      const pg = this.notebook.userData.pageGroup;
      // Slow loop: page rotates 0..25deg over 8s, then resets
      const cycle = (ts % 8) / 8;
      const ang = Math.sin(cycle * Math.PI * 2) * 0.35;
      pg.rotation.z = ang;
    }

    // Dust motes drift
    if (this.dust) {
      const pts = this.dust.userData.points;
      const pos = pts.geometry.getAttribute('position');
      const base = pts.geometry.getAttribute('aBase');
      const seed = pts.geometry.getAttribute('aSeed');
      for (let i = 0; i < pos.count; i++) {
        const phase = seed.getX(i);
        const speed = seed.getY(i);
        const amp   = seed.getZ(i);
        const life = (ts * speed * 0.4 + phase) % (Math.PI * 2);
        const ox = Math.sin(life) * amp * 1.2;
        const oy = Math.cos(life * 0.7) * amp * 0.4;
        const oz = Math.sin(life * 0.5 + phase) * amp;
        pos.setX(i, base.getX(i) + ox);
        pos.setY(i, base.getY(i) + oy);
        pos.setZ(i, base.getZ(i) + oz);
      }
      pos.needsUpdate = true;
    }

    // Subtle desk object idle motion
    if (this.notebook) this.notebook.rotation.y = 0.3 + Math.sin(ts * 0.4) * 0.01;
    if (this.teaCup)   this.teaCup.position.y    = 0.08 + Math.sin(ts * 0.5) * 0.002;

    // Render
    this.renderer.render(this.scene, this.camera);

    this._raf = requestAnimationFrame((tt) => this._animate(tt));
  }

  destroy() {
    cancelAnimationFrame(this._raf);
    window.removeEventListener('resize', this._onResize);
    window.removeEventListener('mousemove', this._onMouseMove);
    window.removeEventListener('touchmove', this._onTouchMove);
    window.removeEventListener('touchend', this._onTouchEnd);
    this.renderer.dispose();
    this.scene.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) {
        if (Array.isArray(o.material)) o.material.forEach((m) => m.dispose());
        else o.material.dispose();
      }
    });
  }
}
