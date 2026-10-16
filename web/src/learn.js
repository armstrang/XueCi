/* ================= Learning engine =================
   Everything below runs on the phone. Nothing is sent anywhere.

   Memory model: FSRS-5 (open-source spaced-repetition model, default parameters fitted on public review data).
   A memory state is [difficulty 1–10, stability in days, last answer in minutes since 1 Jan 2026 UTC]; the chance
   of still recalling after t days is R = (1 + 19/81·t/S)^-0.5, so R = 90 % when t = S.
   Every word has one state for the word (drives scheduling and the 0–20 level) plus one per skill:
     m = meaning (see hanzi → meaning), f = form (meaning → hanzi, sentence gap), s = sound (tones/pinyin, listening).
   Skills decide which kind of question comes next and show weaknesses.

   Level 0–20 = how long the word is expected to stay remembered: 20·ln(1+S)/ln(121), so about 1 month → 14 (green)
   and 4 months → 20. Green also needs a passed form (f) and sound (s) answer. Same-day repeats add at most
   half a day of stability, so a word can't be crammed to green in one sitting.

   Storage (localStorage, this device only; the old keys mm_stats/hsk16_* are untouched):
     xc_mem   {id: {w:[d,s,t], m|f|s:[d,s,t,lastGrade,timesRight], i:firstSeen, L:1 legacy unconfirmed|2 confirmed, p:1 first seen in exam practice}}
     xc_log   recent answers, xc_logA older answers (capped): [t, id, type, grade 1–4, tenths of a second, wrong pick id|0, flags]
              flags: 1 unchecked claim, 2 said "I know", 4 sure but wrong, 8 exam practice, 16 placement test
     xc_goal  {t:'level'|'exam'|'none', lv, date:'YYYY-MM-DD', pace:'min'|'new'|'auto', n}
     xc_lvl   {lv, src:'test'|'manual', at, m: mastered level, per:[6 shares]}  the learner's starting level (default HSK 1);
              the guided plan starts there and moves on by itself once every word of a level has been introduced
     xc_w     {w:[19 parameters], n, at, ll, ll0}   parameters fitted to this learner's own answers (optimize())
   Progress made before this engine existed is kept: each old [right, wrong, level] becomes a state with the same
   level, marked "needs confirming" (L:1) until one form and one sound question have been answered. */
const LM=(()=>{
const EPOCH=Date.UTC(2026,0,1);
const now=()=>Math.round((Date.now()-EPOCH)/6e4);
const TZ=new Date().getTimezoneOffset();
const dayOf=t=>Math.floor((t-TZ)/1440);
const cl=(x,a,b)=>Math.min(b,Math.max(a,x));
const r2=x=>Math.round(x*100)/100,r3=x=>Math.round(x*1000)/1000;

/* ---- FSRS-5 ---- */
const W0=[0.40255,1.18385,3.173,15.69105,7.1949,0.5345,1.4604,0.0046,1.54575,0.1192,1.01925,1.9395,0.11,0.29605,2.2698,0.2315,2.9898,0.51655,0.6621];
const LB=[.01,.01,.01,.01,1,.001,.001,.001,0,0,.001,.001,.001,.001,0,0,1,0,0];
const UB=[100,100,100,100,10,4,4,.75,4.5,.8,3.5,5,.25,.9,4,1,6,2,2];
const DECAY=-.5,FACTOR=19/81;
const Rt=(days,s)=>Math.pow(1+FACTOR*Math.max(0,days)/s,DECAY);
const ivl=(s,r)=>s/FACTOR*(Math.pow(r,1/DECAY)-1);
const D0=(w,g)=>cl(w[4]-Math.exp(w[5]*(g-1))+1,1,10);
const sameDay=(t,t0)=>t-t0<240||dayOf(t)===dayOf(t0);
/* st = [d, s, t] or null for a first answer; prior = share of the word's characters already known (0–1) */
function step(w,st,g,t,prior){
  if(!st){const k=prior||0;return [cl(D0(w,g)-(g>1?1.2*k:0),1,10),Math.max(.1,w[g-1]*(g>2?1+.6*k:1)),t]}
  const d=st[0],s=st[1],el=(t-st[2])/1440;
  const d2=cl(w[7]*D0(w,4)+(1-w[7])*(d-w[6]*(g-3)*(10-d)/9),1,10);
  let s2;
  if(sameDay(t,st[2])){const inc=Math.exp(w[17]*(g-3+w[18]));s2=g>2?Math.min(s*inc,s+.5):s*inc}
  else{const r=Rt(el,s);
    s2=g===1?Math.min(w[11]*Math.pow(d,-w[12])*(Math.pow(s+1,w[13])-1)*Math.exp(w[14]*(1-r)),s/Math.exp(w[17]*w[18]))
      :s*(1+Math.exp(w[8])*(11-d)*Math.pow(s,-w[9])*(Math.exp(w[10]*(1-r))-1)*(g===2?w[15]:1)*(g===4?w[16]:1))}
  return [d2,cl(s2,.1,36500),t]}

/* ---- storage ---- */
let W=W0.slice(),wMeta=null;
{const o=ls.get('xc_w',null);if(o&&Array.isArray(o.w)&&o.w.length===19&&o.w.every(Number.isFinite)){W=o.w;wMeta=o}}
let mem=ls.get('xc_mem',null);if(!mem||typeof mem!=='object'||Array.isArray(mem))mem={};
let goal=ls.get('xc_goal',null);if(!validGoal(goal))goal=null;
let logR=ls.get('xc_log',[]),logA=ls.get('xc_logA',[]);if(!Array.isArray(logR))logR=[];if(!Array.isArray(logA))logA=[];
let logCache=null,confMap=null,charS=null;
const allLog=()=>logCache||(logCache=logA.length?logA.concat(logR):logR.slice());
function logPush(e){logR.push(e);
  if(logR.length>=2000){logA=logA.concat(logR).slice(-28000);ls.set('xc_logA',logA);logR=[]}
  ls.set('xc_log',logR);logCache=null}
let saveT=0;
function flush(){clearTimeout(saveT);saveT=0;ls.set('xc_mem',mem)}
const saveMem=()=>{clearTimeout(saveT);saveT=setTimeout(flush,300)};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&saveT)flush()});
addEventListener('pagehide',()=>{if(saveT)flush()});

const okS=se=>!!se&&se[3]>1;
const LN121=Math.log(121);
function levelOf(e){if(!e||!e.w)return -1;let L=cl(Math.round(20*Math.log(1+e.w[1])/LN121),0,20);
  if(L>13&&e.L!==1&&!(okS(e.f)&&okS(e.s)))L=13;return L}
const skLevel=se=>se?cl(Math.round(20*Math.log(1+se[1])/LN121),0,20):-1;
const isState=a=>Array.isArray(a)&&a.length>=3&&a.slice(0,3).every(Number.isFinite)&&a[0]>=1&&a[0]<=10&&a[1]>0;
function cleanEntry(e){
  if(!e||typeof e!=='object'||!isState(e.w))return null;
  const o={w:[r2(e.w[0]),r3(e.w[1]),Math.round(e.w[2])],i:Number.isFinite(e.i)?Math.round(e.i):0};
  for(const k of ['m','f','s'])if(isState(e[k]))o[k]=[r2(e[k][0]),r3(e[k][1]),Math.round(e[k][2]),cl(e[k][3]|0,1,4),Math.max(0,e[k][4]|0)];
  if(e.L===1||e.L===2)o.L=e.L;if(e.p===1)o.p=1;return o}
for(const id in mem){const c=IDX.has(id)?cleanEntry(mem[id]):null;if(c)mem[id]=c;else delete mem[id]}

/* Keep the old per-word records (stats) and the memory states in step: old progress becomes a state with the
   same level ("needs confirming"); every level is recalculated from the state. */
function sync(){const t=now();
  for(const id in stats){const e=stats[id];if(!IDX.has(id)||e[0]+e[1]<=0||mem[id])continue;
    const L=cl(e[2]|0,0,20),S=Math.max(.1,Math.pow(121,L/20)-1),D=cl(4+6*e[1]/Math.max(1,e[0]+e[1]),1,10);
    mem[id]={w:[r2(D),r3(S),t],i:0,L:1}}
  for(const id in mem){const st=stats[id]||(stats[id]=[0,0,0]);st[2]=Math.max(0,levelOf(mem[id]))}
  charS=null;flush();saveStats()}

/* ---- answering ---- */
const SK={cm:'m',cs:'s',cn:'m',m:'m',f:'f',s:'s',l:'s',c:'f'};
const DEFMS={cm:4500,cs:4500,cu:4500,cn:4500,m:5000,f:6000,s:6000,l:7000,c:9000};
const QUIZ=new Set(['m','f','s','l','c']);
let last=null;
function medMs(q){const L=allLog(),a=[];for(let i=L.length-1;i>=0&&a.length<40&&i>L.length-800;i--){const e=L[i];if(e[2]===q&&e[3]>1)a.push(e[4]*100)}
  if(a.length<8)return DEFMS[q]||6000;a.sort((x,y)=>x-y);return a[a.length>>1]}
function grade(o,e){const med=medMs(o.q);let g=o.ms<=med*1.8?3:2;
  if(g===3&&o.ms<med*.6&&e.w&&e.w[1]>=3&&!/^(m|cm|cu)$/.test(o.q))g=4;return g}
function knownShare(d){
  if(!charS){charS=new Map();for(const id in mem){const x=IDX.get(id),s=mem[id].w[1];for(const c of x.h){if((charS.get(c)||0)<s)charS.set(c,s)}}}
  const cs=[...new Set(d.h)];return cs.filter(c=>(charS.get(c)||0)>=2).length/cs.length}
/* o: {q: type, ok, ms, x: wrong pick id, claim, over: sure but wrong, unchecked, exam} */
function answer(d,o){
  const t=now(),id=d.id,had=mem[id];
  if(o.placement)o.exam=true;
  const flags=(o.unchecked?1:0)|(o.claim?2:0)|(o.over?4:0)|(o.exam?8:0)|(o.placement?16:0),ms=Math.min(9999,Math.round((o.ms||0)/100));
  if(o.exam&&!had&&!o.ok){logPush([t,id,o.q,1,ms,o.x||0,flags]);if(o.x)addConf(id,o.x);return {g:1,before:-1,after:-1}}
  last={id,mem:had?JSON.parse(JSON.stringify(had)):null,st:stats[id]?stats[id].slice():null,n:logR.length};
  const e=had||{i:t},before=levelOf(had),g=o.ok?grade(o,e):1;
  if(!had&&o.exam)e.p=1;                             /* known already (exam practice): not one of today's new words */
  e.w=step(W,e.w,g,t,had?0:knownShare(d));
  if(o.over)e.w[0]=Math.min(10,e.w[0]+1);            /* sure but wrong: the word becomes harder */
  e.w=[r2(e.w[0]),r3(e.w[1]),t];
  const k=o.unchecked?null:SK[o.q];
  if(k){const se=e[k],ns=step(W,se?se.slice(0,3):null,g,t,0);e[k]=[r2(ns[0]),r3(ns[1]),t,g,(se?se[4]:0)+(g>1?1:0)]}
  if(e.L===1&&e.f&&e.s)e.L=2;
  mem[id]=e;
  const st=stats[id]||[0,0,0];if(o.ok)st[0]++;else st[1]++;st[2]=levelOf(e);stats[id]=st;
  logPush([t,id,o.q,g,ms,o.x||0,flags]);
  if(o.x)addConf(id,o.x);
  if(!had)charS=null;
  saveMem();saveStats();
  return {g,before,after:st[2]}}
/* "Turns out I was wrong" right after an unchecked claim: take that answer back */
function undo(){if(!last)return false;const L=last;last=null;
  if(L.mem)mem[L.id]=L.mem;else delete mem[L.id];
  if(L.st)stats[L.id]=L.st;else delete stats[L.id];
  if(logR.length>L.n){logR.length=L.n;ls.set('xc_log',logR);logCache=null}
  charS=null;saveMem();saveStats();return true}

/* ---- confusions: which words get mixed up (from wrong picks) ---- */
const pairKey=(a,b)=>a<b?a+'|'+b:b+'|'+a;
function confs(){if(!confMap){confMap=new Map();for(const e of allLog())if(e[5]&&IDX.has(e[5])){const k=pairKey(e[1],e[5]);confMap.set(k,(confMap.get(k)||0)+1)}}return confMap}
function addConf(a,b){if(!confMap||!IDX.has(b))return;const k=pairKey(a,b);confMap.set(k,(confMap.get(k)||0)+1)}
function partners(id){const out=[];for(const [k,n] of confs()){const [a,b]=k.split('|');if(a===id)out.push([b,n]);else if(b===id)out.push([a,n])}
  return out.sort((x,y)=>y[1]-x[1]).map(x=>x[0])}

/* ---- calibration: how often "I know" turned out right; honest learners get fewer checks ---- */
function calib(){const L=allLog();let n=0,c=0;for(let i=L.length-1;i>=0&&n<40;i--){const e=L[i];if(e[2]==='cm'||e[2]==='cs'){n++;if(e[3]>1)c++}}return {n,acc:n?c/n:0}}
function checkP(d){const e=mem[d.id];if(!e||e.L===1||!(e.m||e.s))return 1;const c=calib();if(c.n<8)return 1;return cl((1-c.acc)*4+.25,.25,1)}
function checkType(d,heard){const e=mem[d.id],t=now();if(heard||!e||!okS(e.m))return 'cm';
  const r=se=>se?Rt((t-se[2])/1440,se[1]):0;return r(e.s)<r(e.m)?'cs':'cm'}

/* ---- question material ---- */
let IX=null;
function ix(){if(IX)return IX;const byChar=new Map(),byPk=new Map(),push=(m,k,v)=>{let a=m.get(k);if(!a)m.set(k,a=[]);a.push(v)};
  DATA.forEach(d=>{for(const c of new Set(d.h))push(byChar,c,d);push(byPk,d.pk,d)});return IX={byChar,byPk}}
const fullPy=d=>d.p.toLowerCase().replace(/['\s]/g,'');
function similar(d){const {byChar,byPk}=ix(),out=[],seen=new Set([d.id]);
  const add=x=>{if(x&&!seen.has(x.id)){seen.add(x.id);out.push(x)}};
  partners(d.id).forEach(id=>add(IDX.get(id)));
  (byPk.get(d.pk)||[]).forEach(add);
  const sh=[];for(const c of new Set(d.h))for(const x of byChar.get(c)||[])if(!seen.has(x.id))sh.push(x);
  const n=[...d.h].length,sc=x=>Math.abs([...x.h].length-n)*2+Math.abs(x.l-d.l)+Math.random();
  [...new Set(sh)].map(x=>[sc(x),x]).sort((a,b)=>a[0]-b[0]).forEach(p=>add(p[1]));return out}
function recentAcc(){const L=allLog();let n=0,c=0;for(let i=L.length-1;i>=0&&n<30;i--){const e=L[i];if(QUIZ.has(e[2])&&!(e[6]&8)){n++;if(e[3]>1)c++}}return {n,acc:n?c/n:0}}
/* how often a wrong option is a look-alike: more for words you know better, adjusted to keep you near 80–85 % right */
function hardness(d){const L=levelOf(mem[d.id]);let h=L<0?.15:L<7?.3:L<14?.6:.85;const a=recentAcc();
  if(a.n>=10){if(a.acc>.88)h+=.15;else if(a.acc<.72)h-=.25}return cl(h,0,1)}
function shuf(a){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.random()*(i+1)|0;[a[i],a[j]]=[a[j],a[i]]}return a}
/* four options: the word plus three others (wrong options never share the word's meaning, and never sound the same in a listening question) */
function wordOpts(d,type,hard){
  const used=new Set([type==='m'?M1(d).toLowerCase():d.h]),fp=fullPy(d),picks=[];
  const dm=M1(d).toLowerCase();
  const okX=x=>{if(x.id===d.id)return false;if(type==='m'){const m=M1(x).toLowerCase();return !!m&&!used.has(m)}
    if(used.has(x.h))return false;if(type==='l'&&fullPy(x)===fp)return false;
    const xm=M1(x).toLowerCase();if(xm===dm||xm.length>2&&dm.length>2&&(xm.includes(dm)||dm.includes(xm)))return false;   /* near-synonyms would make two right answers */
    return true};
  const take=x=>{picks.push(x);used.add(type==='m'?M1(x).toLowerCase():x.h)};
  const h=type==='c'?0:hard!=null?hard:hardness(d),sim=type==='c'?[]:similar(d),n=[...d.h].length;
  const near=BY[d.l].filter(x=>Math.abs(x.u-d.u)<=3);
  const rnd=shuf(near.length>=12?near:BY[d.l]).map(x=>[(type==='m'?0:Math.abs([...x.h].length-n))+Math.random()*1.5,x]).sort((a,b)=>a[0]-b[0]).map(p=>p[1]);
  let si=0,ri=0;
  while(picks.length<3&&(si<sim.length||ri<rnd.length)){
    let x=null;
    if(Math.random()<h)while(si<sim.length&&!x){const c=sim[si++];if(okX(c))x=c}
    while(!x&&ri<rnd.length){const c=rnd[ri++];if(okX(c))x=c}
    while(!x&&si<sim.length){const c=sim[si++];if(okX(c))x=c}
    if(x)take(x);else break}
  return shuf([d,...picks])}
/* tone options: the word's pinyin plus three versions with other tones. 一 and 不 (tone changes) and neutral-tone
   syllables (many also have a dictionary tone, e.g. 出来 chūlai/chūlái) keep theirs, unless nothing else can change */
const MARKS={a:'āáǎà',e:'ēéěè',i:'īíǐì',o:'ōóǒò',u:'ūúǔù','ü':'ǖǘǚǜ'};
const bareSyl=s=>s.normalize('NFD').replace(/[̀́̄̌]/g,'').normalize('NFC');
function markTone(p,t){if(t===5)return p;const low=p.toLowerCase();let i=low.indexOf('a');if(i<0)i=low.indexOf('e');if(i<0&&low.includes('ou'))i=low.indexOf('o');
  if(i<0)for(let j=low.length-1;j>=0;j--)if('iouü'.includes(low[j])){i=j;break}
  if(i<0)return p;const ch=low[i],m=MARKS[ch];if(!m)return p;let r=m[t-1];if(p[i]!==ch)r=r.toUpperCase();return p.slice(0,i)+r+p.slice(i+1)}
const NEAR={1:[4,2,3],2:[3,1,4],3:[2,4,1],4:[1,3,2],5:[4,1,3]};
function toneOpts(d){
  const syl=d.s,ch=[...d.h],key=a=>a.join(' '),seen=new Set([key(syl)]),out=[];
  const can=i=>markTone(bareSyl(syl[i]),1)!==bareSyl(syl[i]);
  let idx=syl.map((_,i)=>i).filter(i=>can(i)&&tone(syl[i])!==5&&!(syl.length===ch.length&&(ch[i]==='一'||ch[i]==='不')));
  if(!idx.length)idx=syl.map((_,i)=>i).filter(can);
  const vary=(a,i,t)=>{const b=a.slice();b[i]=markTone(bareSyl(a[i]),t);return b};
  const near=[],far=[];
  for(const i of idx){const N=NEAR[tone(syl[i])];near.push(vary(syl,i,N[0]),vary(syl,i,N[1]));far.push(vary(syl,i,N[2]))}
  for(let k=0;k<16&&idx.length>1;k++){const i=idx[Math.random()*idx.length|0],j=idx[Math.random()*idx.length|0];if(i===j)continue;
    far.push(vary(vary(syl,i,NEAR[tone(syl[i])][Math.random()*2|0]),j,NEAR[tone(syl[j])][Math.random()*2|0]))}
  for(const v of shuf(near).concat(shuf(far))){if(out.length===3)break;const k=key(v);if(!seen.has(k)){seen.add(k);out.push(v)}}
  const opts=shuf([syl,...out]);return {opts,ans:opts.indexOf(syl)}}
const clozeOK=d=>d.z.includes(d.h);
let ttsReady=()=>false;
/* material for one question: {opts, ans} — ans is the index of the right option */
function question(d,q,hard){
  if(q==='s'||q==='cs')return toneOpts(d);
  const opts=wordOpts(d,q==='cm'?'m':q,hard);return {opts,ans:opts.indexOf(d)}}

/* ---- what to ask next ---- */
const has=(e,k)=>!!e&&!!e[k]&&e[k][4]>0;
let skillW={m:0,f:0,s:0};      /* weakest skill overall gets a nudge */
function pickType(d){const e=mem[d.id],t=now();if(!e)return 'm';
  if(e.L===1){if(!e.f)return 'f';if(!e.s)return 's'}
  const r=se=>se?Rt((t-se[2])/1440,se[1]):0,c=[['m',r(e.m)]];
  if(has(e,'m')||e.L){c.push(['f',r(e.f)]);c.push(['s',r(e.s)])}
  const k=c.map(([k,v])=>[k,v-skillW[k]+Math.random()*.12]).sort((a,b)=>a[1]-b[1])[0][0];
  if(k==='f'&&has(e,'f')&&clozeOK(d)&&Math.random()<.4)return 'c';
  if(k==='s'&&has(e,'s')&&ttsReady()&&Math.random()<.4)return 'l';
  return k}
function dr(g=goal){if(g&&g.t==='exam'&&g.date){const dl=daysTo(g.date);if(dl>=0&&dl<=30)return .9+.05*(1-dl/30)}return .9}
const rNow=(e,t)=>e&&e.w?Rt((t-e.w[2])/1440,e.w[1]):0;
/* words in curriculum order that haven't been seen yet; ones whose characters you already know come a little earlier,
   and two look-alikes (shared character or same syllables) are never introduced together */
function pickNew(n,src){if(n<=0)return [];const cand=[];for(const d of src){if(!mem[d.id])cand.push(d);if(cand.length>=60)break}
  const sc=cand.map((d,i)=>[i-14*knownShare(d),d]).sort((a,b)=>a[0]-b[0]).map(p=>p[1]),out=[],chars=new Set(),pks=new Set();
  for(const d of sc){if(out.length>=n)break;if([...d.h].some(c=>chars.has(c))||pks.has(d.pk))continue;out.push(d);[...d.h].forEach(c=>chars.add(c));pks.add(d.pk)}
  for(const d of sc){if(out.length>=n)break;if(!out.includes(d))out.push(d)}
  return out}
const tsort=a=>a.slice().sort((x,y)=>x.l-y.l||x.n-y.n);
/* Cards: due words first (lowest recall chance), then up to half a round of new ones, then the rest by weakness */
function cardDeck(pool,n){const t=now(),r=dr(),due=[],rest=[];
  for(const d of pool){const e=mem[d.id];if(!e)continue;const R=rNow(e,t);if(R<r)due.push([R,d]);else rest.push([R,d])}
  due.sort((a,b)=>a[0]-b[0]);rest.sort((a,b)=>a[0]-b[0]);
  const out=due.slice(0,n).map(p=>p[1]);
  if(out.length<n)out.push(...pickNew(Math.min(n-out.length,Math.max(4,Math.round(n/2))),tsort(pool)));
  for(const p of rest){if(out.length>=n)break;out.push(p[1])}
  return out.slice(0,n)}
/* Quiz round inside the chosen level/unit; type null = the app chooses per word */
function quizRound(pool,n,type){const t=now(),r=dr(),sc=[];
  const src=type==='c'?pool.filter(clozeOK):pool;
  for(const d of src){const e=mem[d.id];if(!e)continue;const R=rNow(e,t);sc.push([R<r?R:e.L===1?.95:1+R,d])}
  sc.sort((a,b)=>a[0]-b[0]);
  let words=sc.slice(0,n).map(p=>p[1]);
  const fresh=pickNew(Math.max(type?0:3,n-words.length),tsort(src));
  if(!type&&words.length>n-3&&fresh.length)words=words.slice(0,Math.max(0,n-Math.min(3,fresh.length)));
  words=words.concat(fresh).slice(0,n);
  return shuf(words).map(d=>({k:'q',d,q:type||pickType(d)}))}
/* Exam simulation: a uniform sample of the cumulative vocabulary up to the level, mixed question types */
function exam(lv,n){const src=DATA.filter(d=>d.l<=lv),out=[];const seen=new Set();
  while(out.length<n&&seen.size<src.length){const d=src[Math.random()*src.length|0];if(seen.has(d.id))continue;seen.add(d.id);
    const x=Math.random();let q=x<.3?'m':x<.55?'f':x<.75?'s':'c';if(q==='c'&&!clozeOK(d))q='f';if(q==='s'&&ttsReady()&&Math.random()<.4)q='l';
    out.push({k:'q',d,q})}
  return out}

/* ---- current level and the placement test ----
   The placement test is 50 quick questions that adapt to the answers. Ability θ (0–7, "knows the words of HSK levels
   up to θ") has a probability over a grid; each answer updates it with an item-response model:
     P(knows a level-l word | θ) = 1 / (1 + e^(−2.4·(θ − b))),  b = l − 0.5 + type offset
   A learner who knows the word answers right 95 % of the time; one who doesn't presses "Don't know" or guesses one of
   four options (25 % right). The next question aims at the current estimate. Words come from a bank of words that
   bring characters new at their level (so they can't be worked out from easier words); HSK 5–6 only get the hard
   question types (recall with look-alike options, tones, sentence gaps). A level counts as mastered when θ is at
   least that level with 80 % certainty (90 % for HSK 5 and 6, which also need at least 5 questions of that level,
   70 % right), and every level below it is mastered too. Strong learners get HSK 5 and 6 questions in turn. */
let lvInfo=ls.get('xc_lvl',null);if(!lvInfo||!LEVELS.includes(lvInfo.lv))lvInfo=null;
const baseLevel=()=>lvInfo?lvInfo.lv:1;
function curLevel(){for(let l=baseLevel();l<=6;l++)if(BY[l].some(d=>!mem[d.id]))return l;return 6}
function setLevel(lv,src,extra){lvInfo=Object.assign({lv,src,at:now()},extra||{});ls.set('xc_lvl',lvInfo)}
const PT={N:50,K:2.4,G:.25,SLIP:.04,IDK:.6,DQ:{m:-.3,f:0,s:.1,c:.2},TYPES:{1:'mfs',2:'mfs',3:'mfsc',4:'mfsc',5:'fsc',6:'fsc'}};
const GRID=Array.from({length:71},(_,i)=>i/10);
let PB=null;
function placementBank(){if(PB)return PB;PB={};const seen=new Set();
  for(const l of LEVELS){PB[l]=BY[l].filter(d=>{const c=[...d.h];return c.length<=4&&(l<3||c.length>=2)&&(l===1||c.some(x=>!seen.has(x)))&&d.m.split(';')[0].length<=28&&clozeOK(d)});
    BY[l].forEach(d=>{for(const c of d.h)seen.add(c)})}
  return PB}
const pKnow=(th,b)=>1/(1+Math.exp(-PT.K*(th-b)));
const itemB=(l,q)=>l-.5+PT.DQ[q]+(l>=5?.15:0);
/* idk = how often this learner presses "Don't know" instead of guessing, estimated from their own answers, so a
   learner who guesses everything doesn't get credit for lucky guesses */
function likelihood(r,pk,idk){const nk=1-pk;return r==='ok'?pk*(1-PT.SLIP)+nk*(1-idk)*PT.G:r==='idk'?pk*.01+nk*idk:pk*(PT.SLIP-.01)+nk*(1-idk)*(1-PT.G)}
function posterior(st){const n=r=>st.items.filter(x=>x.r===r).length,a=n('idk')*(1-PT.G),idk=cl((a+PT.IDK*2)/(a+n('ng')+2),.03,.95);
  let post=GRID.map(t=>-t/3.5);
  for(const it of st.items){const b=itemB(it.l,it.q);post=post.map((p,i)=>p+Math.log(likelihood(it.r,pKnow(GRID[i],b),idk)))}
  const mx=Math.max(...post);post=post.map(p=>Math.exp(p-mx));const s=post.reduce((x,y)=>x+y,0);return post.map(p=>p/s)}
function ptStats(st){const post=st.post=posterior(st);let m=0,v=0;GRID.forEach((t,i)=>m+=t*post[i]);GRID.forEach((t,i)=>v+=(t-m)*(t-m)*post[i]);return {mean:m,sd:Math.sqrt(v)}}
function ptStart(){placementBank();return {post:null,items:[],used:new Set(),chars:new Set()}}
/* the next question: three warm-ups (HSK 1, 2, 3), then aimed at the estimate, with a little spread */
function ptNext(st){const n=st.items.length;if(n>=PT.N)return null;
  const {mean,sd}=ptStats(st);
  let l=n<3?n+1:Math.round(mean+.5+(Math.random()-.5)*Math.min(1.2,sd));l=cl(l,1,6);
  if(n>=3&&mean>=4.3){const c5=st.items.filter(x=>x.l===5).length,c6=st.items.filter(x=>x.l===6).length;l=c5===c6?(mean>=5.5?6:5):c5<c6?5:6}   /* strong learners: test HSK 5 and 6 evenly */
  const types=PT.TYPES[l],cnt=q=>st.items.filter(x=>x.q===q).length;
  const q=[...types].sort((a,b)=>cnt(a)-cnt(b)+(Math.random()-.5)*.5)[0];
  const pool=PB[l].filter(d=>!st.used.has(d.id)&&!(q==='c'&&!clozeOK(d)));
  const fresh=pool.filter(d=>![...d.h].some(c=>st.chars.has(c)));   /* no shared characters with earlier questions (no hints) */
  const src=fresh.length?fresh:pool,d=src[Math.random()*src.length|0];
  st.used.add(d.id);[...d.h].forEach(c=>st.chars.add(c));
  const it={d,l,q};Object.assign(it,question(d,q,l>=4?.85:.5));return it}
function ptAnswer(st,it,r){it.r=r;st.items.push(it)}
function ptResult(st){const {mean,sd}=ptStats(st),ge=l=>GRID.reduce((a,t,i)=>a+(t>=l-1e-9?st.post[i]:0),0);
  const pass=l=>{if(ge(l)<(l>=5?.9:.8))return false;if(l<5)return true;const it=st.items.filter(x=>x.l===l),ok=it.filter(x=>x.r==='ok').length;return it.length>=5&&ok/it.length>=.7};
  let m=0;for(const l of LEVELS){if(pass(l))m=l;else break}
  const per=LEVELS.map(l=>Math.round(GRID.reduce((a,t,i)=>a+st.post[i]*pKnow(t,l-.5),0)*100));
  const right=st.items.filter(x=>x.r==='ok').length,idk=st.items.filter(x=>x.r==='idk').length;
  return {m,lv:Math.min(6,m+1),mean,sd,per,right,idk,n:st.items.length}}

/* ---- goals and the daily plan ---- */
function validGoal(g){return !!g&&typeof g==='object'&&['level','exam','none'].includes(g.t)&&
  (g.t==='none'||(LEVELS.includes(g.lv)&&/^\d{4}-\d\d-\d\d$/.test(g.date||'')))&&['min','new','auto'].includes(g.pace)&&(g.pace==='auto'||g.n>0)}
function daysTo(date){const [y,m,d]=date.split('-').map(Number),a=new Date(y,m-1,d),b=new Date();b.setHours(0,0,0,0);return Math.round((a-b)/864e5)}
function dayAfter(n){const d=new Date();d.setHours(12,0,0,0);d.setDate(d.getDate()+Math.round(n));return d}
const isoDay=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
/* seconds per review / per new word, learned from your own answering speed */
function pace(){const L=allLog(),a=[],c=[];for(let i=L.length-1;i>=0&&i>L.length-600;i--){const e=L[i];if(QUIZ.has(e[2]))a.push(e[4]/10);else if(e[2][0]==='c')c.push(e[4]/10)}
  const med=x=>{x.sort((p,q)=>p-q);return x[x.length>>1]};
  return {rev:a.length>=15?cl(med(a)+4,5,30):10,neu:c.length>=10?cl(med(c)+24,18,60):30}}
/* days until every target word has been introduced; with a minutes-per-day budget the reviews of words already
   learned take a growing share of the time (about 0.08 reviews a day per word), so fewer new words fit later on */
function finishDays(g,nd,remaining,load,sp){
  if(g.pace!=='min')return nd>0?Math.ceil(remaining/nd):null;
  const perNew=sp.neu+2.5*sp.rev;let rem=remaining,l=load,d=0;
  while(rem>0&&d<1500){const n=cl(Math.floor((g.n*60-l*sp.rev)/perNew),0,40);if(n<=0)return null;rem-=n;l+=n*.08;d++}
  return rem>0?null:d}
/* the fewest minutes a day that still introduce every target word in time (null if even 4 hours a day can't) */
function minutesFor(remaining,load,sp,limit){const fd=m=>finishDays({pace:'min',n:m},0,remaining,load,sp);
  const ok=m=>{const d=fd(m);return d!==null&&d<=limit};if(!ok(240))return null;let lo=1,hi=240;
  while(lo<hi){const m=(lo+hi)>>1;if(ok(m))hi=m;else lo=m+1}return lo}
function plan(g=goal){
  const t=now(),today=dayOf(t),r=dr(g),sp=pace();
  let due=0,load=0,introT=0;
  for(const id in mem){const e=mem[id];if(rNow(e,t)<r)due++;load+=1/Math.max(1,ivl(e.w[1],r));if(e.i&&!e.p&&dayOf(e.i)===today)introT++}
  let ansT=0,secT=0;const L=allLog();for(let i=L.length-1;i>=0;i--){const e=L[i];if(dayOf(e[0])!==today)break;ansT++;secT+=e[4]/10+4}
  const P={t:g?g.t:'none',due,introT,ansT,minT:Math.round(secT/60),sp};
  let remaining=null,need=0,days=null,buffer=0;
  /* words below the starting level count as known; a goal below it is already reached */
  if(g&&g.t!=='none'){const lo=baseLevel(),tw=g.lv>=lo?DATA.filter(d=>d.l<=g.lv&&d.l>=lo):[];remaining=tw.filter(d=>!mem[d.id]).length;
    days=daysTo(g.date);buffer=g.t==='exam'?Math.min(7,Math.floor(Math.max(0,days)/4)):Math.min(3,Math.floor(Math.max(0,days)/5));
    need=remaining?Math.ceil(remaining/Math.max(1,days-buffer)):0;P.lv=g.lv;P.date=g.date}
  P.remaining=remaining;P.need=need;P.days=days;
  const perNew=sp.neu+2.5*sp.rev;
  let nd;
  if(g&&g.pace==='min')nd=cl(Math.floor((g.n*60-load*sp.rev)/perNew),0,40);
  else if(g&&g.pace==='new')nd=g.n;
  else nd=remaining!==null?cl(need,3,40):10;
  if(remaining===0)nd=0;
  if(g&&g.t==='exam'&&days!==null&&days<=7)nd=0;
  if(remaining!==null&&remaining>0)nd=Math.min(nd,remaining);
  P.newPerDay=nd;P.revPerDay=Math.round(load+nd*2.5);
  P.minutes=Math.max(1,Math.round((P.revPerDay*sp.rev+nd*sp.neu)/60));
  P.needMin=remaining?minutesFor(remaining,load,sp,Math.max(1,days-buffer)):null;
  P.newToday=Math.max(0,nd-introT);
  /* reviews today are capped by the daily time (or 1.5× a normal day), most at-risk first, so days off never pile up */
  let cap=Math.max(0,Math.max(20,Math.round(P.revPerDay*1.5))-ansT);
  if(g&&g.pace==='min')cap=Math.max(0,Math.floor((g.n*60-secT-P.newToday*sp.neu)/sp.rev));
  P.revToday=Math.min(due,cap);
  if(!g||g.t==='none')P.status='free';
  else if(days<0)P.status='past';
  else if(remaining===0)P.status='review';
  else if(g.t==='exam'&&days<=7)P.status='examweek';
  else{const fd=finishDays(g,nd,remaining,load,sp);P.finish=fd===null?null:dayAfter(fd);
    P.status=fd!==null&&fd<=days-buffer?'ok':'behind';
    /* a later date that works: at this pace, or (if the reviews would fill the time first) at 20 new words a day */
    if(P.status==='behind'){const fdays=fd===null?Math.ceil(remaining/20)+buffer:fd+buffer;P.fixDate=fdays>days?dayAfter(fdays):null}}
  P.todayLeft=P.newToday*2+P.revToday;return P}
/* today's session: due reviews (most at risk first), up to three old green words to confirm, new words as cards
   (in curriculum order from the current level up to the goal's level) */
function session(extra){
  const P=plan(),t=now(),r=dr();
  const lo=curLevel(),src=tsort(DATA.filter(d=>d.l>=lo&&(!goal||goal.t==='none'||d.l<=Math.max(goal.lv,lo))));
  let rev=[],conf=[];
  const all=[];for(const id in mem){const e=mem[id];all.push([rNow(e,t),IDX.get(id),e])}
  all.sort((a,b)=>a[0]-b[0]);
  if(extra)rev=all.slice(0,12).map(p=>p[1]);
  else{rev=all.filter(p=>p[0]<r).slice(0,P.revToday).map(p=>p[1]);
    conf=all.filter(p=>p[2].L===1&&levelOf(p[2])>13&&!rev.includes(p[1])).sort((a,b)=>levelOf(b[2])-levelOf(a[2])).slice(0,3).map(p=>p[1])}
  const fresh=pickNew(extra?5:P.newToday,src);
  const q=rev.map(d=>({k:'q',d,q:pickType(d)}));
  conf.forEach(d=>{const e=mem[d.id];if(!e.f)q.push({k:'q',d,q:'f'});if(!e.s)q.push({k:'q',d,q:'s'})});
  const items=shuf(q),out=[];let k=0;
  for(const d of fresh){out.push(...items.splice(0,k?3:1));out.push({k:'card',d,isNew:true});k++}
  return out.concat(items)}

/* ---- insights for the Stats screen ---- */
function insights(){
  const t=now(),L=allLog(),acc={},cnt={};let n7=0,ver=0;
  for(let i=L.length-1;i>=0;i--){const e=L[i];if(t-e[0]<7*1440)n7++;if(!(e[6]&1))ver++;
    const q=e[2];if(QUIZ.has(q)&&(cnt[q]||0)<150){cnt[q]=(cnt[q]||0)+1;acc[q]=(acc[q]||0)+(e[3]>1?1:0)}}
  const skills={};for(const q of ['m','f','s','l','c'])if(cnt[q])skills[q]={n:cnt[q],p:Math.round(acc[q]/cnt[q]*100)};
  let rs=0,rn=0;for(const id in mem){rs+=rNow(mem[id],t);rn++}
  const pairs=[...confs()].filter(p=>p[1]>=1).sort((a,b)=>b[1]-a[1]).slice(0,3).map(([k,c])=>{const [a,b]=k.split('|');return [IDX.get(a),IDX.get(b),c]});
  const weak=Object.entries(skills).filter(p=>p[1].n>=10).sort((a,b)=>a[1].p-b[1].p)[0];
  return {recall:rn?Math.round(rs/rn*100):null,n7,cal:calib(),skills,weak:weak&&weak[1].p<85?weak[0]:null,pairs,verified:ver,total:L.length,
    spaced:lossOf(W,seqs()).n,model:wMeta?{n:wMeta.n,at:wMeta.at}:null,need:MINFIT}}
function updWeak(){const s=insights().skills,a=k=>{const q=k==='m'?['m']:k==='f'?['f','c']:['s','l'];let n=0,p=0;q.forEach(x=>{if(s[x]){n+=s[x].n;p+=s[x].p*s[x].n}});return n>=10?p/n/100:null};
  for(const k of ['m','f','s']){const v=a(k);skillW[k]=v===null?0:cl((.9-v)*.6,0,.25)}}

/* ---- personalising the model: fit the 19 parameters to this learner's own answers (on the phone) ---- */
const MINFIT=400;
function seqs(){const by=new Map();for(const e of allLog().slice(-12000)){if(e[6]&1)continue;const m=mem[e[1]];if(m&&m.L)continue;
  let a=by.get(e[1]);if(!a)by.set(e[1],a=[]);a.push([e[0],e[3]])}return [...by.values()]}
function lossOf(w,S){let ll=0,n=0;for(const q of S){let st=null;for(const [t,g] of q){
  if(st&&!sameDay(t,st[2])){const p=cl(Rt((t-st[2])/1440,st[1]),1e-4,1-1e-4);ll-=g>1?Math.log(p):Math.log(1-p);n++}st=step(w,st,g,t,0)}}return {ll,n}}
let fitting=false;
async function optimize(force){
  if(fitting)return null;const S=seqs(),base=lossOf(W0,S);if(base.n<MINFIT&&!force)return null;if(!base.n)return null;
  fitting=true;try{
  const sc=W0.map(x=>Math.max(.05,Math.abs(x)*.5)),N=base.n;
  const toW=z=>z.map((v,i)=>cl(W0[i]+v*sc[i],LB[i],UB[i]));
  const f=z=>lossOf(toW(z),S).ll/N+2/N*z.reduce((s,v)=>s+v*v,0);
  let z=W0.map(()=>0),m=z.map(()=>0),v=z.map(()=>0),fz=f(z);const lr=.06,eps=.01;
  /* small slices of work between frames, so the app stays smooth while this runs */
  const idle=()=>new Promise(r=>window.requestIdleCallback?requestIdleCallback(()=>r(),{timeout:250}):setTimeout(r,16));
  for(let it=1;it<=50;it++){
    const g=[];for(let i=0;i<19;i++){const z2=z.slice();z2[i]+=eps;g.push((f(z2)-fz)/eps);if(i%4===3)await idle()}
    z=z.map((zi,i)=>{m[i]=.9*m[i]+.1*g[i];v[i]=.999*v[i]+.001*g[i]*g[i];const mh=m[i]/(1-Math.pow(.9,it)),vh=v[i]/(1-Math.pow(.999,it));return zi-lr*mh/(Math.sqrt(vh)+1e-8)});
    z=toW(z).map((w,i)=>(w-W0[i])/sc[i]);fz=f(z);
    await idle()}
  const w=toW(z),ll=lossOf(w,S).ll/N,ll0=base.ll/N;
  ls.set('xc_fit',{at:now(),len:allLog().length});
  if(ll<ll0-.002){W=w.map(x=>Math.round(x*1e4)/1e4);wMeta={w:W,n:N,at:now(),ll:r3(ll),ll0:r3(ll0)};ls.set('xc_w',wMeta)}
  return {ll,ll0,n:N,used:ll<ll0-.002}}finally{fitting=false}}
function maybeOptimize(){const o=ls.get('xc_fit',null),L=allLog().length;
  if(o&&(now()-o.at<1440||L-o.len<100))return;optimize(false).catch(()=>{})}

/* ---- backup, reset, history ---- */
function exportMem(){flush();return mem}
function importMem(o){if(!o||typeof o!=='object'||Array.isArray(o))return null;const out={};
  for(const id in o){if(!IDX.has(id))continue;const c=cleanEntry(o[id]);if(c)out[id]=c}return out}
function replace(m,g,w){mem=m||{};if(g!==undefined){goal=validGoal(g)?g:null;ls.set('xc_goal',goal)}
  if(Array.isArray(w)&&w.length===19&&w.every((x,i)=>Number.isFinite(x)&&x>=LB[i]&&x<=UB[i])){W=w.slice();wMeta={w:W,n:0,at:now()};ls.set('xc_w',wMeta)}
  confMap=null;charS=null;last=null;sync()}
function forget(id){delete mem[id];charS=null;saveMem()}
function clearLog(){logR=[];logA=[];logCache=null;confMap=null;last=null;ls.set('xc_log',[]);ls.set('xc_logA',[]);
  W=W0.slice();wMeta=null;try{localStorage.removeItem('xc_w');localStorage.removeItem('xc_fit')}catch(e){}skillW={m:0,f:0,s:0}}

sync();updWeak();
return {now,dayOf,Rt,step,W0,get W(){return W},levelOf,skLevel,okS,answer,undo,checkP,checkType,question,pickType,cardDeck,quizRound,exam,session,
  plan,dr,isoDay,dayAfter,daysTo,validGoal,curLevel,baseLevel,get level(){return lvInfo},setLevel,ptStart,ptNext,ptAnswer,ptResult,PT,placementBank,get goal(){return goal},setGoal(g){goal=validGoal(g)?g:null;ls.set('xc_goal',goal)},
  mem:id=>mem[id],has:id=>!!mem[id],rNow:id=>rNow(mem[id],now()),nextDue(id){const e=mem[id];if(!e)return null;return (e.w[2]+ivl(e.w[1],dr())*1440-now())/1440},
  insights,updWeak,optimize,maybeOptimize,lossOf,seqs,exportMem,importMem,replace,forget,clearLog,sync,flush,allLog,partners,
  setTts(f){ttsReady=f},clozeOK,markTone,bareSyl,get params(){return wMeta?W:null}}})();
