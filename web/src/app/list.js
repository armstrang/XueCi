/* ---------- list ---------- */
const view = $('view');
function itemH(d, q) {
  return `<article class="item" tabindex="0">
      <div class="ihead"><div class="head"><span class="hz">${hzH(d)}</span><span class="py">${pyH(d)}</span>${spk(d.h)}</div>
      <span class="nos">${q ? chip(d.l) : ''}<i class="sd ${mcls(d)}" title="${esc(stTxt(d))}"></i><span class="no">${String(d.n).padStart(4, '0')}</span></span></div>
      <div class="mean">${mH(M(d))}</div>
      <div class="ex"><div class="zh">${exH(d)}${spk(d.z, ' sm')}</div>${zpH(d)}<div class="id">${esc(TR(d))}</div></div>
    </article>`;
}
const LATIN_ONLY = /^[\u0000-ɏḀ-ỿ\s]*$/;
function renderList() {
  const q = state.q.trim().toLowerCase(),
    qp = LATIN_ONLY.test(state.q) ? plain(state.q) : '';
  let p = q ? DATA.filter(d => d.key.includes(q) || (qp && d.key.includes(qp))) : pool();
  if (state.weak) p = p.filter(d => !isKnown(d));
  const total = p.length,
    list = p.slice(0, state.shown),
    L = state.level,
    u = unit();
  const label = q
    ? L10.results(fmt(total), esc(state.q))
    : (u ? `No. ${(u - 1) * 50 + 1}–${Math.min(u * 50, BY[L].length)} · ` : '') + L10.words(fmt(total));
  /* the first dozen words paint at once: opening the list never stalls a slow phone */
  const tok = ++listTok,
    first = list.slice(0, 12);
  view.innerHTML =
    `<p class="meta">${label}</p>` +
    (total
      ? `<div class="list ${state.hide ? 'hidemean' : ''}" id="listEl">${first.map(d => itemH(d, q)).join('')}</div>` +
        (total > state.shown
          ? `<button class="more" id="more">${L10.more(Math.min(60, total - state.shown))}</button>`
          : '')
      : `<div class="empty">${L10.empty}</div>`);
  /* the rest follow in small batches, one per frame */
  const more = from => {
    if (tok !== listTok || !$('listEl') || from >= list.length) return;
    $('listEl').insertAdjacentHTML(
      'beforeend',
      list
        .slice(from, from + 12)
        .map(d => itemH(d, q))
        .join(''),
    );
    requestAnimationFrame(() => more(from + 12));
  };
  if (list.length > 12) requestAnimationFrame(() => more(12));
}
let listTok = 0;
view.addEventListener('click', e => {
  if (state.screen === 'list' && e.target.id === 'more') {
    state.shown += 60;
    renderList();
  }
});
$('q').oninput = e => {
  state.q = e.target.value;
  state.shown = 60;
  renderList();
};
const hideBtn = $('hideMean'),
  weakBtn = $('onlyNew');
hideBtn.onclick = () => {
  state.hide = !state.hide;
  hideBtn.setAttribute('aria-pressed', state.hide);
  renderList();
};
weakBtn.onclick = () => {
  state.weak = !state.weak;
  weakBtn.setAttribute('aria-pressed', state.weak);
  state.shown = 60;
  renderList();
};
