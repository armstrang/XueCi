/* ================= Soul Sea (识海): the soul orb and the wheel of five elements =================
   The orb is the learner's word memory drawn as a network on a sphere: one point per learned word (up to 900, the
   strongest and most recent), lines between words that share a character, brightness = chance of recalling the word
   now, colour = its HSK level. The core in the middle shows the realm (凡人 mist … 飞升 radiance), its size the stage.
   Drawn on a 2D canvas with a simple 3D projection; it turns slowly, can be turned with a finger, and stops after
   10 s without a touch, when the page is hidden, or always when the phone asks for reduced motion.
   The wheel around it has five petals (五行), one per attribute from LM.soul(); petal length = value. */
const SOUL=(()=>{
const EL=[['wood','木','cult'],['fire','火','insight'],['earth','土','root'],['metal','金','dao'],['water','水','sense']];   /* clockwise from the top, generating cycle */
let cv=null,ctx=null,nodes=[],edges=[],rot=0,tilt=.38,raf=0,last=0,idle=0,drag=null,realmN=0,stageI=0,colors={},onPick=null,flash=0,bolt=null;
const reduce=()=>{try{return matchMedia('(prefers-reduced-motion: reduce)').matches}catch(e){return false}};
function hash(s){let h=2166136261;for(const c of s){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return (h>>>0)/4294967296}
function build(){
  const t=LM.now(),list=[];for(const d of DATA){const e=LM.mem(d.id);if(e)list.push([d,e])}
  list.sort((a,b)=>b[1].w[1]-a[1].w[1]);const keep=list.slice(0,900).sort((a,b)=>a[0].l-b[0].l||a[0].n-b[0].n);
  const N=keep.length,ga=Math.PI*(3-Math.sqrt(5));
  nodes=keep.map(([d,e],i)=>{const y=N>1?1-2*(i+.5)/N:0,r=Math.sqrt(1-y*y),th=i*ga+hash(d.id)*.6;
    const mist=realmN===0?.55+.45*hash(d.id+'r'):1;   /* before the first test the points are a loose mist */
    return {d,x:Math.cos(th)*r*mist,y:y*mist,z:Math.sin(th)*r*mist,R:LM.Rt((t-e.w[2])/1440,e.w[1]),s:Math.min(1,Math.log(1+e.w[1])/Math.log(121)),l:d.l}});
  const byChar=new Map();nodes.forEach((n,i)=>{for(const c of new Set(n.d.h)){let a=byChar.get(c);if(!a)byChar.set(c,a=[]);a.push(i)}});
  const deg=new Array(N).fill(0);edges=[];
  for(const a of byChar.values()){for(let k=1;k<a.length&&edges.length<700;k++){const i=a[k-1],j=a[k];if(deg[i]<3&&deg[j]<3){edges.push([i,j]);deg[i]++;deg[j]++}}}}
function readColors(){const cs=getComputedStyle(document.body);for(let l=1;l<=6;l++)colors[l]=cs.getPropertyValue('--l'+l).trim()||'#888';
  colors.fg=cs.getPropertyValue('--fg').trim();colors.acc=cs.getPropertyValue('--acc').trim();colors.dark=typeof isDark==='function'&&isDark()}
function rgba(hex,a){const m=/^#?([0-9a-f]{6})$/i.exec(hex);if(!m)return `rgba(128,128,128,${a})`;const v=parseInt(m[1],16);return `rgba(${v>>16&255},${v>>8&255},${v&255},${a})`}
function core(c,cx,cy,R,time){
  const k=.75+.09*stageI,gold=['#fff3c4','#ffd76a','#c9922b'];
  if(realmN>=5){const g=c.createRadialGradient(cx,cy,R*.2,cx,cy,R*1.35);g.addColorStop(0,rgba(colors.acc,.22));g.addColorStop(1,rgba(colors.acc,0));c.fillStyle=g;c.beginPath();c.arc(cx,cy,R*1.35,0,7);c.fill()}
  if(realmN===7){c.save();c.translate(cx,cy);c.rotate(time/9000);for(let i=0;i<12;i++){c.rotate(Math.PI/6);const g=c.createLinearGradient(0,0,R*1.3,0);g.addColorStop(0,'rgba(255,240,190,.55)');g.addColorStop(1,'rgba(255,240,190,0)');c.fillStyle=g;c.beginPath();c.moveTo(0,-2);c.lineTo(R*1.3,-.5);c.lineTo(R*1.3,.5);c.lineTo(0,2);c.fill()}c.restore()}
  if(realmN===0)return;
  const glow=c.createRadialGradient(cx,cy,0,cx,cy,R*.55*k);glow.addColorStop(0,rgba(realmN>=3?'#ffd76a':colors.acc,.55));glow.addColorStop(1,rgba(realmN>=3?'#ffd76a':colors.acc,0));
  c.fillStyle=glow;c.beginPath();c.arc(cx,cy,R*.55*k,0,7);c.fill();
  if(realmN>=2){c.save();c.strokeStyle=realmN>=3?'rgba(214,170,70,.75)':rgba(colors.acc,.6);c.lineWidth=1.6;c.beginPath();c.ellipse(cx,cy+R*.32,R*.42*k,R*.09*k,0,0,7);c.stroke();c.restore()}
  if(realmN>=3){const pulse=realmN>=4?1+.05*Math.sin(time/500):1,r=R*.16*k*pulse,g=c.createRadialGradient(cx-r*.3,cy-r*.3,r*.1,cx,cy,r);
    g.addColorStop(0,gold[0]);g.addColorStop(.45,gold[1]);g.addColorStop(1,gold[2]);c.fillStyle=g;c.beginPath();c.arc(cx,cy,r,0,7);c.fill()}
  if(realmN>=4){c.fillStyle='rgba(255,255,255,.9)';c.beginPath();c.arc(cx,cy,R*.055*k,0,7);c.fill()}
  if(realmN===1||realmN===2){for(let i=0;i<3;i++){const a=time/1400+i*2.1,rr=R*(.3+.06*i);c.fillStyle=rgba(colors.acc,.8);c.beginPath();c.arc(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr*.45,2.2,0,7);c.fill()}}}
function frame(time){
  raf=0;if(!cv||!cv.isConnected)return;
  const w=cv.width,h=cv.height,cx=w/2,cy=h/2,R=w*.44,dpr=window.devicePixelRatio||1,c=ctx;
  c.clearRect(0,0,w,h);
  const ca=Math.cos(rot),sa=Math.sin(rot),ct=Math.cos(tilt),st=Math.sin(tilt);
  const P=nodes.map(n=>{const x=n.x*ca+n.z*sa,z1=-n.x*sa+n.z*ca,y=n.y*ct-z1*st,z=n.y*st+z1*ct;return [cx+x*R,cy+y*R,z]});
  c.lineWidth=dpr*.7;
  for(const [i,j] of edges){const a=P[i],b=P[j],dz=(a[2]+b[2])/2;c.strokeStyle=rgba(colors.fg,(.035+.09*(dz+1)/2)*(colors.dark?1.2:1));c.beginPath();c.moveTo(a[0],a[1]);c.lineTo(b[0],b[1]);c.stroke()}
  const order=P.map((p,i)=>i).sort((a,b)=>P[a][2]-P[b][2]);
  let drewCore=false;
  for(const i of order){const p=P[i],n=nodes[i];if(!drewCore&&p[2]>0){core(c,cx,cy,R,time);drewCore=true}
    const depth=(p[2]+1)/2,a=(.18+.82*n.R)*(.3+.7*depth),r=dpr*(.9+1.9*n.s)*(.7+.5*depth);
    c.fillStyle=rgba(colors[n.l],a);c.beginPath();c.arc(p[0],p[1],r,0,7);c.fill();
    if(flash&&n.flash){c.strokeStyle=rgba(colors[n.l],.6*flash);c.lineWidth=dpr;c.beginPath();c.arc(p[0],p[1],r+4*dpr*(1-flash),0,7);c.stroke()}}
  if(!drewCore)core(c,cx,cy,R,time);
  if(realmN===6){if(!bolt&&Math.random()<.006){const a=Math.random()*6.28,pts=[];let x=cx+Math.cos(a)*R*.95,y=cy+Math.sin(a)*R*.95;for(let k=0;k<7;k++){pts.push([x,y]);x+=(cx-x)*.18+(Math.random()-.5)*R*.18;y+=(cy-y)*.18+(Math.random()-.5)*R*.18}bolt={pts,until:time+240}}
    if(bolt){c.strokeStyle='rgba(205,190,255,.85)';c.lineWidth=1.6*dpr;c.beginPath();bolt.pts.forEach((q,k)=>k?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]));c.stroke();if(time>bolt.until)bolt=null}}
  cv._P=P;
  if(flash>0)flash=Math.max(0,flash-.02);
  const dt=last?Math.min(50,time-last):16;last=time;
  if(!drag)rot+=dt*.00018;
  if(!reduce()&&!document.hidden&&state.screen==='soul'&&(time-idle<10000||drag))raf=requestAnimationFrame(frame);else last=0}
function wake(){idle=performance.now();if(!raf&&cv&&!reduce())raf=requestAnimationFrame(frame)}
function mount(canvas,opts){
  cv=canvas;ctx=cv.getContext('2d');realmN=opts.realm;stageI=opts.stage;onPick=opts.onPick;readColors();build();
  const dpr=window.devicePixelRatio||1,size=cv.clientWidth||220;cv.width=Math.round(size*dpr);cv.height=Math.round(size*dpr);
  const week=LM.now()-7*1440;nodes.forEach(n=>{const e=LM.mem(n.d.id);n.flash=!!(e&&e.k&&e.k>week)});flash=1;   /* words that became solid this week light up once */
  idle=performance.now();cancelAnimationFrame(raf);raf=0;
  if(reduce())frame(0);else raf=requestAnimationFrame(frame);
  cv.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,moved:false};try{cv.setPointerCapture(e.pointerId)}catch(_){}wake()};
  cv.onpointermove=e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(Math.abs(dx)+Math.abs(dy)>4)drag.moved=true;
    rot+=dx*.01;tilt=Math.max(-1.1,Math.min(1.1,tilt+dy*.006));drag.x=e.clientX;drag.y=e.clientY;wake();if(reduce())frame(0)};
  cv.onpointerup=e=>{const d=drag;drag=null;wake();if(d&&!d.moved&&cv._P){const r=cv.getBoundingClientRect(),x=(e.clientX-r.left)*cv.width/r.width,y=(e.clientY-r.top)*cv.height/r.height;
    let best=-1,bd=(16*(window.devicePixelRatio||1))**2;cv._P.forEach((p,i)=>{if(p[2]<0)return;const q=(p[0]-x)**2+(p[1]-y)**2;if(q<bd){bd=q;best=i}});onPick&&onPick(best>=0?nodes[best].d:null)}};
  cv.onpointercancel=()=>{drag=null}}
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&state.screen==='soul')wake()});
/* the five petals: SVG, W×W; null values are drawn as a dashed outline */
function wheel(S,W){const c=W/2,r0=W*.3,lmax=W*.12,ring=W*.455,vals=EL.map(e=>S[e[2]]),known=vals.filter(v=>v!==null),min=known.length?Math.min(...known):null;
  let h=`<svg class="wheel" viewBox="0 0 ${W} ${W}" aria-hidden="true"><circle class="ring" cx="${c}" cy="${c}" r="${ring}"/><g class="petals">`;
  EL.forEach(([k,g,key],i)=>{const v=S[key],a=-90+i*72,L=lmax*(.18+.82*(v===null?.35:v/100)),b=W*.05;
    const path=`M0,0 C${-b*1.15},${L*.22} ${-b*1.05},${L*.78} 0,${L} C${b*1.05},${L*.78} ${b*1.15},${L*.22} 0,0 Z`;   /* a leaf: narrow at the orb, round in the middle */
    h+=`<g transform="translate(${c},${c}) rotate(${a+90}) translate(0,${-r0}) scale(1,-1)"><path class="petal el-${k}${v===null?' unk':''}${v!==null&&v===min&&known.length>1?' weak':''}" d="${path}"/></g>`});
  h+=`</g>`;
  EL.forEach(([k,g],i)=>{const a=(-90+i*72)*Math.PI/180,x=c+Math.cos(a)*ring,y=c+Math.sin(a)*ring;
    h+=`<g class="elg el-${k}"><circle cx="${x}" cy="${y}" r="${W*.05}"/><text x="${x}" y="${y}" dy=".36em" text-anchor="middle" font-size="${W*.055}">${g}</text></g>`});
  return h+'</svg>'}
return {mount,wheel,wake,EL,flashAll(){flash=1;wake()}}})();
