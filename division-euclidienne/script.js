// ---------- proof grid (Activité, division a-j) ----------
const proofData = [
  { letter:"a.", value:"95 × 7 = 665", readonly:true },
  { letter:"b.", value:"38 × 6 + 1 = 229", readonly:true },
  { letter:"c.", value:"", readonly:false },
  { letter:"d.", value:"", readonly:false },
  { letter:"e.", value:"", readonly:false },
  { letter:"f.", value:"", readonly:false },
  { letter:"g.", value:"", readonly:false },
  { letter:"h.", value:"", readonly:false },
  { letter:"i.", value:"", readonly:false },
  { letter:"j.", value:"", readonly:false }
];
const proofGrid = document.getElementById('proofGrid');
proofData.forEach(p => {
  const div = document.createElement('div');
  div.className = 'proof-item';
  div.innerHTML = `<div class="letter">${p.letter}</div><input type="text" placeholder="Preuve : … × … + … = …" value="${p.value}" ${p.readonly ? 'readonly' : ''}>`;
  proofGrid.appendChild(div);
});

// ---------- Exercice 1 : tableaux de divisions euclidiennes ----------
const eqRowsData = [
  { mode:"num", dividende:47, diviseur:6, quotient:null, reste:null },
  { mode:"num", dividende:92, diviseur:9, quotient:10, reste:null },
  { mode:"num", dividende:130, diviseur:20, quotient:null, reste:10 },
  { mode:"dragdrop", dividende:205, diviseur:11, quotient:18, reste:7 },
  { mode:"dropdown", dividende:76, diviseur:8, quotient:9, reste:4 }
];
const eqRowsEl = document.getElementById('eqRows');

eqRowsData.forEach((row, rowIdx) => {
  const wrap = document.createElement('div');
  wrap.className = 'eq-row';

  if (row.mode === 'num') {
    wrap.innerHTML = `
      <div class="eq-kind">Complète les nombres manquants</div>
      <div class="eq-line">
        <span>${row.dividende}</span> <span>=</span> <span>${row.diviseur}</span> <span>×</span>
        <span class="num-slot">${row.quotient === null ? `<input type="text" data-row="${rowIdx}" data-field="quotient">` : row.quotient}</span>
        <span>+</span>
        <span class="num-slot">${row.reste === null ? `<input type="text" data-row="${rowIdx}" data-field="reste">` : row.reste}</span>
      </div>
      <div class="eq-labels">
        <span class="label-slot">Dividende</span><span class="label-slot">Diviseur</span>
        <span class="label-slot">Quotient</span><span class="label-slot">Reste</span>
      </div>
    `;
  } else if (row.mode === 'dragdrop') {
    wrap.innerHTML = `
      <div class="eq-kind">Fais glisser la bonne étiquette sous chaque nombre</div>
      <div class="eq-line">
        <span>${row.dividende}</span> <span>=</span> <span>${row.diviseur}</span> <span>×</span>
        <span>${row.quotient}</span> <span>+</span> <span>${row.reste}</span>
      </div>
      <div class="eq-labels">
        <div class="drop-zone" data-row="${rowIdx}" data-answer="Dividende"></div>
        <div class="drop-zone" data-row="${rowIdx}" data-answer="Diviseur"></div>
        <div class="drop-zone" data-row="${rowIdx}" data-answer="Quotient"></div>
        <div class="drop-zone" data-row="${rowIdx}" data-answer="Reste"></div>
      </div>
      <div class="tile-bank" data-row="${rowIdx}">
        <div class="tile" draggable="true" data-label="Dividende">Dividende</div>
        <div class="tile" draggable="true" data-label="Diviseur">Diviseur</div>
        <div class="tile" draggable="true" data-label="Quotient">Quotient</div>
        <div class="tile" draggable="true" data-label="Reste">Reste</div>
      </div>
    `;
  } else if (row.mode === 'dropdown') {
    const opts = `<option value="">…</option><option>Dividende</option><option>Diviseur</option><option>Quotient</option><option>Reste</option>`;
    wrap.innerHTML = `
      <div class="eq-kind">Choisis le bon nom sous chaque nombre</div>
      <div class="eq-line">
        <span>${row.dividende}</span> <span>=</span> <span>${row.diviseur}</span> <span>×</span>
        <span>${row.quotient}</span> <span>+</span> <span>${row.reste}</span>
      </div>
      <div class="eq-labels">
        <select class="label-select">${opts}</select>
        <select class="label-select">${opts}</select>
        <select class="label-select">${opts}</select>
        <select class="label-select">${opts}</select>
      </div>
    `;
  }
  eqRowsEl.appendChild(wrap);
});

// drag & drop wiring
let draggedTile = null;
eqRowsEl.querySelectorAll('.tile').forEach(tile => {
  tile.addEventListener('dragstart', () => { draggedTile = tile; });
});
eqRowsEl.querySelectorAll('.drop-zone').forEach(zone => {
  zone.addEventListener('dragover', e => { e.preventDefault(); zone.classList.add('dragover'); });
  zone.addEventListener('dragleave', () => zone.classList.remove('dragover'));
  zone.addEventListener('drop', e => {
    e.preventDefault();
    zone.classList.remove('dragover');
    if (!draggedTile) return;
    zone.textContent = draggedTile.dataset.label;
    zone.classList.add('filled');
    draggedTile.classList.add('used');
    draggedTile.setAttribute('draggable', 'false');
    draggedTile = null;
  });
});

// ---------- Exercice 2 : vrai/faux + justification ----------
const vfEquations = [
  "53 = 6 × 8 + 5",
  "41 = 5 × 7 + 6",
  "100 = 9 × 11 + 2",
  "77 = 10 × 7 + 7",
  "48 = 8 × 5 + 8",
  "63 = 7 × 9 + 0"
];
const vfEqList = document.getElementById('vfEqList');
vfEquations.forEach((eq, i) => {
  const div = document.createElement('div');
  div.className = 'vf-item';
  div.innerHTML = `
    <div class="vf-text vf-eq-text">${eq}</div>
    <div class="vf-toggle">
      <button type="button" data-v="vrai">Vrai</button>
      <button type="button" data-v="faux">Faux</button>
    </div>
    <div class="vf-justif"><input type="text" placeholder="Justifie ta réponse…"></div>
  `;
  vfEqList.appendChild(div);
});
vfEqList.querySelectorAll('.vf-toggle button').forEach(btn => {
  btn.addEventListener('click', () => {
    const group = btn.closest('.vf-toggle');
    group.querySelectorAll('button').forEach(b => b.classList.remove('sel-vrai','sel-faux'));
    btn.classList.add(btn.dataset.v === 'vrai' ? 'sel-vrai' : 'sel-faux');
  });
});

// ---------- Vrai/Faux toggle exercise (Section II) ----------
const vfStatements = [
  "2 × 8 = 16  →  16 est un diviseur de 2 ?",
  "4 × 5 = 20  →  20 est le multiple de 5 ?",
  "6 × 7 = 42  →  6 et 7 sont des diviseurs de 42 ?"
];
const vfList = document.getElementById('vfList');
vfStatements.forEach((text, i) => {
  const div = document.createElement('div');
  div.className = 'vf-item';
  div.innerHTML = `
    <div class="vf-text">${text}</div>
    <div class="vf-toggle">
      <button type="button" data-i="${i}" data-v="vrai">Vrai</button>
      <button type="button" data-i="${i}" data-v="faux">Faux</button>
    </div>
  `;
  vfList.appendChild(div);
});
vfList.querySelectorAll('.vf-toggle button').forEach(btn => {
  btn.addEventListener('click', () => {
    const group = btn.closest('.vf-toggle');
    group.querySelectorAll('button').forEach(b => b.classList.remove('sel-vrai','sel-faux'));
    btn.classList.add(btn.dataset.v === 'vrai' ? 'sel-vrai' : 'sel-faux');
  });
});

// ---------- print & reset ----------
document.getElementById('printBtn').addEventListener('click', () => window.print());
document.getElementById('resetBtn').addEventListener('click', () => {
  if (!confirm('Effacer toutes les réponses saisies ?')) return;
  document.querySelectorAll('input[type=text]:not([readonly])').forEach(i => i.value = '');
  document.querySelectorAll('.vf-toggle button').forEach(b => b.classList.remove('sel-vrai','sel-faux'));
  document.querySelectorAll('.label-select').forEach(s => s.value = '');
  document.querySelectorAll('.drop-zone').forEach(z => { z.textContent=''; z.classList.remove('filled'); });
  document.querySelectorAll('.tile').forEach(t => { t.classList.remove('used'); t.setAttribute('draggable','true'); });
});