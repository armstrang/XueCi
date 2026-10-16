/* ================= Soul Sea (识海): the soul orb and the wheel of five elements =================
   The orb is the learner's word memory drawn as a network on a sphere: one point per learned word (up to 900, the
   strongest), lines between words that share a character, brightness = chance of recalling the word now, colour = its
   HSK level. The core in the middle shows the realm (凡人 mist … 飞升 radiance), its size the stage.
   Drawn on a 2D canvas with a simple 3D projection. To stay smooth on phones every frame is a handful of draw calls:
   points are sorted into colour × brightness buckets (one path each) and lines into a back and a front path; the
   positions live in typed arrays, so nothing is allocated per frame. It turns slowly, can be spun with a finger (it
   keeps the spin and slows down), eases to a stop after 10 s without a touch, and doesn't draw while the page is
   hidden, scrolled out of view, during the screen transition, or when the phone asks for reduced motion.
   The wheel around it has five leaves (五行), one per attribute from LM.soul(): a faint outline shows the full size,
   the filled leaf grows from the orb with the value. */
const SOUL=(()=>{
const EL=[['wood','木','cult'],['fire','火','insight'],['earth','土','root'],['metal','金','dao'],['water','水','sense']];   /* clockwise from the top, generating cycle */
const BASE=.00018,AB=[.14,.3,.5,.72,.95],NB=6*AB.length;   /* base spin (rad/ms); brightness buckets */
let cv=null,ctx=null,N=0,nodes=[],X,Y,Z,PX,PY,PZ,BK,ORD,CNT=new Int32Array(2*NB+1),edges=new Int32Array(0),
  rot=0,tilt=.38,vel=BASE,raf=0,last=0,idle=0,drag=null,realmN=0,stageI=0,colors={},onPick=null,flash=0,bolt=null,inView=true,io=null,startT=0;
const reduce=()=>{try{return matchMedia('(prefers-reduced-motion: reduce)').matches}catch(e){return false}};
const DPR=()=>Math.min(2,window.devicePixelRatio||1);
function hash(s){let h=2166136261;for(const c of s){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return (h>>>0)/4294967296}
function build(){
  const t=LM.now(),list=[];for(const d of DATA){const e=LM.mem(d.id);if(e)list.push([d,e])}
  list.sort((a,b)=>b[1].w[1]-a[1].w[1]);const keep=list.slice(0,900).sort((a,b)=>a[0].l-b[0].l||a[0].n-b[0].n);
  N=keep.length;const ga=Math.PI*(3-Math.sqrt(5)),week=t-7*1440;
  X=new Float32Array(N);Y=new Float32Array(N);Z=new Float32Array(N);PX=new Float32Array(N);PY=new Float32Array(N);PZ=new Float32Array(N);BK=new Uint8Array(N);ORD=new Int32Array(N);
  nodes=keep.map(([d,e],i)=>{const y=N>1?1-2*(i+.5)/N:0,r=Math.sqrt(1-y*y),th=i*ga+hash(d.id)*.6;
    const mist=realmN===0?.55+.45*hash(d.id+'r'):1;   /* before the first test the points are a loose mist */
    X[i]=Math.cos(th)*r*mist;Y[i]=y*mist;Z[i]=Math.sin(th)*r*mist;
    return {d,R:LM.Rt((t-e.w[2])/1440,e.w[1]),s:Math.min(1,Math.log(1+e.w[1])/Math.log(121)),l:d.l,flash:!!(e.k&&e.k>week)}});
  const byChar=new Map();nodes.forEach((n,i)=>{for(const c of new Set(n.d.h)){let a=byChar.get(c);if(!a)byChar.set(c,a=[]);a.push(i)}});
  const deg=new Uint8Array(N),E=[];
  for(const a of byChar.values()){for(let k=1;k<a.length&&E.length<1400;k++){const i=a[k-1],j=a[k];if(deg[i]<3&&deg[j]<3){E.push(i,j);deg[i]++;deg[j]++}}}
  edges=Int32Array.from(E)}
function readColors(){const cs=getComputedStyle(document.body);for(let l=1;l<=6;l++)colors[l]=cs.getPropertyValue('--l'+l).trim()||'#888';
  colors.fg=cs.getPropertyValue('--fg').trim()||'#888';colors.acc=cs.getPropertyValue('--acc').trim();colors.dark=typeof isDark==='function'&&isDark()}
function rgba(hex,a){const m=/^#?([0-9a-f]{6})$/i.exec(hex);if(!m)return `rgba(128,128,128,${a})`;const v=parseInt(m[1],16);return `rgba(${v>>16&255},${v>>8&255},${v&255},${a})`}
function core(c,cx,cy,R,time){
  const k=.75+.09*stageI,gold=['#fff3c4','#ffd76a','#c9922b'];
  if(realmN===0){const g=c.createRadialGradient(cx,cy,0,cx,cy,R*.5);g.addColorStop(0,rgba(colors.fg,.10));g.addColorStop(1,rgba(colors.fg,0));c.fillStyle=g;c.beginPath();c.arc(cx,cy,R*.5,0,7);c.fill();return}
  if(realmN>=5){const g=c.createRadialGradient(cx,cy,R*.2,cx,cy,R*1.35);g.addColorStop(0,rgba(colors.acc,.22));g.addColorStop(1,rgba(colors.acc,0));c.fillStyle=g;c.beginPath();c.arc(cx,cy,R*1.35,0,7);c.fill()}
  if(realmN===7){c.save();c.translate(cx,cy);c.rotate(time/9000);c.fillStyle='rgba(255,240,190,.22)';c.beginPath();
    for(let i=0;i<12;i++){c.rotate(Math.PI/6);c.moveTo(0,-2);c.lineTo(R*1.3,-.5);c.lineTo(R*1.3,.5);c.lineTo(0,2)}c.fill();c.restore()}
  const glow=c.createRadialGradient(cx,cy,0,cx,cy,R*.55*k),gc=realmN>=3?'#ffd76a':colors.acc;glow.addColorStop(0,rgba(gc,.55));glow.addColorStop(1,rgba(gc,0));
  c.fillStyle=glow;c.beginPath();c.arc(cx,cy,R*.55*k,0,7);c.fill();
  if(realmN>=2){c.strokeStyle=realmN>=3?'rgba(214,170,70,.75)':rgba(colors.acc,.6);c.lineWidth=1.6;c.beginPath();c.ellipse(cx,cy+R*.32,R*.42*k,R*.09*k,0,0,7);c.stroke()}
  if(realmN>=3){const pulse=realmN>=4?1+.05*Math.sin(time/500):1,r=R*.16*k*pulse,g=c.createRadialGradient(cx-r*.3,cy-r*.3,r*.1,cx,cy,r);
    g.addColorStop(0,gold[0]);g.addColorStop(.45,gold[1]);g.addColorStop(1,gold[2]);c.fillStyle=g;c.beginPath();c.arc(cx,cy,r,0,7);c.fill()}
  if(realmN>=4){c.fillStyle='rgba(255,255,255,.9)';c.beginPath();c.arc(cx,cy,R*.055*k,0,7);c.fill()}
  if(realmN===1||realmN===2){c.fillStyle=rgba(colors.acc,.8);c.beginPath();for(let i=0;i<3;i++){const a=time/1400+i*2.1,rr=R*(.3+.06*i),x=cx+Math.cos(a)*rr,y=cy+Math.sin(a)*rr*.45;c.moveTo(x+2.2,y);c.arc(x,y,2.2,0,7)}c.fill()}}
/* one half of the sphere: lines, then points by colour and brightness bucket */
function half(c,front,r0){
  c.globalAlpha=front?(colors.dark?.16:.12):(colors.dark?.07:.05);c.strokeStyle=colors.fg;c.beginPath();
  for(let k=0;k<edges.length;k+=2){const i=edges[k],j=edges[k+1];if((PZ[i]+PZ[j]>=0)!==front)continue;c.moveTo(PX[i],PY[i]);c.lineTo(PX[j],PY[j])}c.stroke();
  const off=front?NB:0;
  for(let b=0;b<NB;b++){const s=CNT[off+b],e=CNT[off+b+1];if(s===e)continue;c.globalAlpha=AB[b%AB.length];c.fillStyle=colors[1+(b/AB.length|0)];c.beginPath();
    for(let q=s;q<e;q++){const i=ORD[q],dep=(PZ[i]+1)/2,r=r0*(.9+1.9*nodes[i].s)*(.7+.5*dep);c.moveTo(PX[i]+r,PY[i]);c.arc(PX[i],PY[i],r,0,6.2832)}c.fill()}
  c.globalAlpha=1}
function draw(time){
  const w=cv.width,h=cv.height,cx=w/2,cy=h/2,R=w*.44,dpr=DPR(),c=ctx;
  c.clearRect(0,0,w,h);
  const ca=Math.cos(rot),sa=Math.sin(rot),ct=Math.cos(tilt),st=Math.sin(tilt);
  CNT.fill(0);
  for(let i=0;i<N;i++){const x=X[i]*ca+Z[i]*sa,z1=-X[i]*sa+Z[i]*ca,y=Y[i]*ct-z1*st,z=Y[i]*st+z1*ct;PX[i]=cx+x*R;PY[i]=cy+y*R;PZ[i]=z;
    const n=nodes[i],a=(.18+.82*n.R)*(.3+.7*(z+1)/2);let ab=0;while(ab<AB.length-1&&a>(AB[ab]+AB[ab+1])/2)ab++;
    const b=(z>=0?NB:0)+(n.l-1)*AB.length+ab;BK[i]=b;CNT[b+1]++}
  for(let b=0;b<2*NB;b++)CNT[b+1]+=CNT[b];
  {const pos=CNT.slice(0,2*NB);for(let i=0;i<N;i++)ORD[pos[BK[i]]++]=i}
  c.lineWidth=dpr*.7;
  half(c,false,dpr);core(c,cx,cy,R,time);half(c,true,dpr);
  if(flash>0){c.lineWidth=dpr;for(let i=0;i<N;i++){if(!nodes[i].flash||PZ[i]<0)continue;c.globalAlpha=.6*flash;c.strokeStyle=colors[nodes[i].l];c.beginPath();c.arc(PX[i],PY[i],dpr*(3+5*(1-flash)),0,6.2832);c.stroke()}c.globalAlpha=1}
  if(realmN===6&&time){if(!bolt&&Math.random()<.006){const a=Math.random()*6.28,pts=[];let x=cx+Math.cos(a)*R*.95,y=cy+Math.sin(a)*R*.95;for(let k=0;k<7;k++){pts.push([x,y]);x+=(cx-x)*.18+(Math.random()-.5)*R*.18;y+=(cy-y)*.18+(Math.random()-.5)*R*.18}bolt={pts,until:time+240}}
    if(bolt){c.strokeStyle='rgba(205,190,255,.85)';c.lineWidth=1.6*dpr;c.beginPath();bolt.pts.forEach((q,k)=>k?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]));c.stroke();if(time>bolt.until)bolt=null}}}
const running=()=>!reduce()&&!document.hidden&&inView&&state.screen==='soul'&&cv&&cv.isConnected;
function frame(time){
  raf=0;if(!cv||!cv.isConnected)return;
  const dt=last?Math.min(50,time-last):16;last=time;
  /* spin: a flick keeps turning and settles back to the slow base speed; after 8 s without a touch it eases to a stop */
  const calm=drag?0:Math.max(0,Math.min(1,(10000-(time-idle))/2000));
  if(!drag){vel+=(BASE*calm-vel)*Math.min(1,dt/450);rot+=vel*dt}
  if(flash>0)flash=Math.max(0,flash-dt/900);
  draw(time);
  if(running()&&(drag||calm>0||Math.abs(vel)>2e-6||flash>0))raf=requestAnimationFrame(frame);else last=0}
function wake(){idle=performance.now();if(!raf&&running())raf=requestAnimationFrame(frame)}
function mount(canvas,opts){
  cancelAnimationFrame(raf);raf=0;last=0;clearTimeout(startT);if(io)io.disconnect();
  cv=canvas;ctx=cv.getContext('2d');realmN=opts.realm;stageI=opts.stage;onPick=opts.onPick;readColors();build();
  const size=cv.clientWidth||200;cv.width=Math.round(size*DPR());cv.height=Math.round(size*DPR());
  flash=nodes.some(n=>n.flash)?1:0;vel=BASE;inView=true;
  draw(0);   /* a still first frame; the motion starts after the screen transition, so the zoom stays smooth */
  if(!reduce())startT=setTimeout(wake,330);
  if('IntersectionObserver' in window){io=new IntersectionObserver(es=>{inView=es[0].isIntersecting;if(inView)wake()});io.observe(cv)}
  let vx=0,lt=0;
  cv.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,moved:false};vx=0;lt=performance.now();try{cv.setPointerCapture(e.pointerId)}catch(_){}wake()};
  cv.onpointermove=e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y,t=performance.now();if(Math.abs(dx)+Math.abs(dy)>4)drag.moved=true;
    rot+=dx*.01;tilt=Math.max(-1.1,Math.min(1.1,tilt+dy*.006));vx=.7*vx+.3*(dx*.01/Math.max(8,t-lt));lt=t;drag.x=e.clientX;drag.y=e.clientY;
    wake();if(reduce())draw(0)};
  cv.onpointerup=e=>{const d=drag;drag=null;vel=Math.max(-.012,Math.min(.012,performance.now()-lt<80?vx:0))||BASE;wake();
    if(d&&!d.moved){const r=cv.getBoundingClientRect(),x=(e.clientX-r.left)*cv.width/r.width,y=(e.clientY-r.top)*cv.height/r.height;
      let best=-1,bd=(16*DPR())**2;for(let i=0;i<N;i++){if(PZ[i]<0)continue;const q=(PX[i]-x)**2+(PY[i]-y)**2;if(q<bd){bd=q;best=i}}onPick&&onPick(best>=0?nodes[best].d:null)}};
  cv.onpointercancel=()=>{drag=null;wake()}}
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&state.screen==='soul')wake()});
/* the five leaves, SVG W×W. Geometry (fractions of W): orb canvas radius .27 · leaves .28–.39 · element badges on a
   ring of .44 with radius .046, so every badge stays inside the picture (the top one used to be cut off). */
function wheel(S,W){const c=W/2,r0=W*.28,lmax=W*.11,ring=W*.44,gr=W*.046,known=EL.filter(e=>S[e[2]]!==null);
  const lo=known.length>1?known.reduce((a,b)=>S[b[2]]<S[a[2]]?b:a):null,hi=known.length>1?known.reduce((a,b)=>S[b[2]]>S[a[2]]?b:a):null,flat=lo&&hi&&S[lo[2]]===S[hi[2]];
  const leaf=L=>{const b=L*.34;return `M0,0 C${-b*1.25},${L*.24} ${-b*1.15},${L*.8} 0,${L} C${b*1.15},${L*.8} ${b*1.25},${L*.24} 0,0 Z`};
  let h=`<svg class="wheel" viewBox="0 0 ${W} ${W}" aria-hidden="true"><circle class="ring" cx="${c}" cy="${c}" r="${ring}"/>`;
  EL.forEach((e,i)=>{const [k,,key]=e,v=S[key],a=-90+i*72,cls=`el-${k}${!flat&&e===lo?' weak':''}${!flat&&e===hi?' strong':''}`;
    h+=`<g class="${cls}" transform="translate(${c},${c}) rotate(${a+90}) translate(0,${-r0}) scale(1,-1)"><path class="ghost" d="${leaf(lmax)}" vector-effect="non-scaling-stroke"/>`+
      (v===null?'':`<path class="petal" d="${leaf(lmax)}" transform="scale(${Math.max(.16,v/100).toFixed(3)})" vector-effect="non-scaling-stroke"/>`)+'</g>'});
  EL.forEach((e,i)=>{const [k,g]=e,a=(-90+i*72)*Math.PI/180,x=(c+Math.cos(a)*ring).toFixed(1),y=(c+Math.sin(a)*ring).toFixed(1);
    h+=`<g class="elg el-${k}${!flat&&e===lo?' weak':''}${!flat&&e===hi?' strong':''}"><circle cx="${x}" cy="${y}" r="${gr}"/><text x="${x}" y="${y}" dy=".36em" text-anchor="middle" font-size="${(W*.05).toFixed(1)}">${g}</text></g>`});
  return h+'</svg>'}
return {mount,wheel,wake,EL,flashAll(){flash=1;wake()}}})();
