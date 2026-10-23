import{A as Gg,An as hu,Br as um,Cr as qS,Ct as T,Dn as gn,Fn as ii,Fr as tg,Gn as jf,Ht as XO,J as Lv,Jn as k,Lr as tm,Lt as WS,Mn as ia,N as HS,On as gu,Or as re,Pn as ig,Pr as t_,Pt as Vo,Qn as kf,Qt as ZO,Rr as tr,S as Eo,Sr as pt$1,U as Ke,Un as jS,Ut as Xa,Vn as j$1,Vr as ut$1,Wr as vo,Xt as Yn,Z as Mi,_n as dS,a as $p,ai as z,ci as zp,cn as _s,dr as ng,ft as Qp,g as D,h as Cm,hn as cm,hr as og,i as $f,j as Gp,jr as rm,kr as rg,kt as Ug,lr as mh,mr as oe,on as _h,pr as nr,qt as YO,rn as _,st as Pe,tt as No,un as aS,vr as om,x as En,yn as eg,zt as Wf}from"./chunk-P_QYOzhA.js";import{a as O,c as j$2,o as Oe$1,s as R,t as $e}from"./chunk-CLZTcgtz.js";var ce=new WeakMap;var V=(()=>{class a{_appRef;_injector=D(oe);_environmentInjector=D(re);load(e){let t=this._appRef=this._appRef||this._injector.get(ii),n=ce.get(t);n||(n={loaders:new Set,refs:[]},ce.set(t,n),t.onDestroy(()=>{ce.get(t)?.refs.forEach(r=>r.destroy()),ce.delete(t)})),n.loaders.has(e)||(n.loaders.add(e),n.refs.push(t_(e,{environmentInjector:this._environmentInjector})))}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var bt=(()=>{class a{static ɵfac=function(t){return new(t||a)};static ɵcmp=aS({type:a,selectors:[[`structural-styles`]],decls:0,vars:0,template:function(t,n){},styles:[`.mat-focus-indicator {
  position: relative;
}
.mat-focus-indicator::before {
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  position: absolute;
  box-sizing: border-box;
  pointer-events: none;
  display: var(--%NS%mat-focus-indicator-display, none);
  border-width: var(--%NS%mat-focus-indicator-border-width, 3px);
  border-style: var(--%NS%mat-focus-indicator-border-style, solid);
  border-color: var(--%NS%mat-focus-indicator-border-color, transparent);
  border-radius: var(--%NS%mat-focus-indicator-border-radius, 4px);
}
.mat-focus-indicator:focus-visible::before {
  content: "";
}

@media (forced-colors: active) {
  html {
    --%NS%mat-focus-indicator-display: block;
    --%NS%mat-focus-indicator-fallback-border-style: none;
  }
}
`],encapsulation:2})}return a})();function W(a){return a.buttons===0||a.detail===0}function K(a){let i=a.touches&&a.touches[0]||a.changedTouches&&a.changedTouches[0];return!!i&&i.identifier===-1&&(i.radiusX==null||i.radiusX===1)&&(i.radiusY==null||i.radiusY===1)}var Ce;function ht(){if(Ce==null){let a=typeof document<`u`?document.head:null;Ce=!!(a&&(a.createShadowRoot||a.attachShadow))}return Ce}function ke(a){if(ht()){let i=a.getRootNode?a.getRootNode():null;if(typeof ShadowRoot<`u`&&ShadowRoot&&i instanceof ShadowRoot)return i}return null}function I(a){if(a.composedPath)try{return a.composedPath()[0]}catch{}return a.target}var G;function ut(){if(G==null&&typeof window<`u`)try{window.addEventListener(`test`,null,Object.defineProperty({},"passive",{get:()=>G=!0}))}finally{G=G||!1}return G}function U(a){return ut()?a:!!a.capture}var pt=new k(`cdk-input-modality-detector-options`);var _t={ignoreKeys:[18,17,224,91,16]};var ft=650;var we={passive:!0,capture:!0};var gt=(()=>{class a{_platform=D(O);_listenerCleanups;modalityDetected;modalityChanged;get mostRecentModality(){return this._modality.value}_mostRecentTarget=null;_modality=new gn(null);_options;_lastTouchMs=0;_onKeydown=e=>{this._options?.ignoreKeys?.some(t=>t===e.keyCode)||(this._modality.next(`keyboard`),this._mostRecentTarget=I(e))};_onMousedown=e=>{Date.now()-this._lastTouchMs<ft||(this._modality.next(W(e)?`keyboard`:`mouse`),this._mostRecentTarget=I(e))};_onTouchstart=e=>{if(K(e)){this._modality.next(`keyboard`);return}this._lastTouchMs=Date.now(),this._modality.next(`touch`),this._mostRecentTarget=I(e)};constructor(){let e=D(Pe),t=D(vo),n=D(pt,{optional:!0});if(this._options=j$1(j$1({},_t),n),this.modalityDetected=this._modality.pipe(tg(1)),this.modalityChanged=this.modalityDetected.pipe($f()),this._platform.isBrowser){let r=D(Yn).createRenderer(null,null);this._listenerCleanups=e.runOutsideAngular(()=>[r.listen(t,`keydown`,this._onKeydown,we),r.listen(t,`mousedown`,this._onMousedown,we),r.listen(t,`touchstart`,this._onTouchstart,we)])}}ngOnDestroy(){this._modality.complete(),this._listenerCleanups?.forEach(e=>e())}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var Q=(function(a){return a[a.IMMEDIATE=0]=`IMMEDIATE`,a[a.EVENTUAL=1]=`EVENTUAL`,a})(Q||{});var vt=new k(`cdk-focus-monitor-default-options`);var de=U({passive:!0,capture:!0});var Ee=(()=>{class a{_ngZone=D(Pe);_platform=D(O);_inputModalityDetector=D(gt);_origin=null;_lastFocusOrigin=null;_windowFocused=!1;_windowFocusTimeoutId;_originTimeoutId;_originFromTouchInteraction=!1;_elementInfo=new Map;_monitoredElementCount=0;_rootNodeFocusListenerCount=new Map;_detectionMode;_windowFocusListener=()=>{this._windowFocused=!0,this._windowFocusTimeoutId=setTimeout(()=>this._windowFocused=!1)};_document=D(vo);_stopInputModalityDetector=new z;constructor(){let e=D(vt,{optional:!0});this._detectionMode=e?.detectionMode||Q.IMMEDIATE}_rootNodeFocusAndBlurListener=e=>{let t=I(e);for(let n=t;n;n=n.parentElement)e.type===`focus`?this._onFocus(e,n):this._onBlur(e,n)};monitor(e,t=!1){let n=Oe$1(e);if(!this._platform.isBrowser||n.nodeType!==1)return kf();let r=ke(n)||this._document,s=this._elementInfo.get(n);if(s)return t&&(s.checkChildren=!0),s.subject;let c={checkChildren:t,subject:new z,rootNode:r};return this._elementInfo.set(n,c),this._registerGlobalListeners(c),c.subject}stopMonitoring(e){let t=Oe$1(e),n=this._elementInfo.get(t);n&&(n.subject.complete(),this._setClasses(t),this._elementInfo.delete(t),this._removeGlobalListeners(n))}focusVia(e,t,n){let r=Oe$1(e);r===this._document.activeElement?this._getClosestElementsInfo(r).forEach(([c,_])=>this._originChanged(c,t,_)):(this._setOrigin(t),typeof r.focus==`function`&&r.focus(n))}ngOnDestroy(){this._elementInfo.forEach((e,t)=>this.stopMonitoring(t))}_getWindow(){return this._document.defaultView||window}_getFocusOrigin(e){return this._origin?this._originFromTouchInteraction?this._shouldBeAttributedToTouch(e)?`touch`:`program`:this._origin:this._windowFocused&&this._lastFocusOrigin?this._lastFocusOrigin:e&&this._isLastInteractionFromInputLabel(e)?`mouse`:`program`}_shouldBeAttributedToTouch(e){return this._detectionMode===Q.EVENTUAL||!!e?.contains(this._inputModalityDetector._mostRecentTarget)}_setClasses(e,t){e.classList.toggle(`cdk-focused`,!!t),e.classList.toggle(`cdk-touch-focused`,t===`touch`),e.classList.toggle(`cdk-keyboard-focused`,t===`keyboard`),e.classList.toggle(`cdk-mouse-focused`,t===`mouse`),e.classList.toggle(`cdk-program-focused`,t===`program`)}_setOrigin(e,t=!1){this._ngZone.runOutsideAngular(()=>{if(this._origin=e,this._originFromTouchInteraction=e===`touch`&&t,this._detectionMode===Q.IMMEDIATE){clearTimeout(this._originTimeoutId);let n=this._originFromTouchInteraction?ft:1;this._originTimeoutId=setTimeout(()=>this._origin=null,n)}})}_onFocus(e,t){let n=this._elementInfo.get(t),r=I(e);!n||!n.checkChildren&&t!==r||this._originChanged(t,this._getFocusOrigin(r),n)}_onBlur(e,t){let n=this._elementInfo.get(t);!n||n.checkChildren&&e.relatedTarget instanceof Node&&t.contains(e.relatedTarget)||(this._setClasses(t),this._emitOrigin(n,null))}_emitOrigin(e,t){e.subject.observers.length&&this._ngZone.run(()=>e.subject.next(t))}_registerGlobalListeners(e){if(!this._platform.isBrowser)return;let t=e.rootNode,n=this._rootNodeFocusListenerCount.get(t)||0;n||this._ngZone.runOutsideAngular(()=>{t.addEventListener(`focus`,this._rootNodeFocusAndBlurListener,de),t.addEventListener(`blur`,this._rootNodeFocusAndBlurListener,de)}),this._rootNodeFocusListenerCount.set(t,n+1),++this._monitoredElementCount===1&&(this._ngZone.runOutsideAngular(()=>{this._getWindow().addEventListener(`focus`,this._windowFocusListener)}),this._inputModalityDetector.modalityDetected.pipe(og(this._stopInputModalityDetector)).subscribe(r=>{this._setOrigin(r,!0)}))}_removeGlobalListeners(e){let t=e.rootNode;if(this._rootNodeFocusListenerCount.has(t)){let n=this._rootNodeFocusListenerCount.get(t);n>1?this._rootNodeFocusListenerCount.set(t,n-1):(t.removeEventListener(`focus`,this._rootNodeFocusAndBlurListener,de),t.removeEventListener(`blur`,this._rootNodeFocusAndBlurListener,de),this._rootNodeFocusListenerCount.delete(t))}--this._monitoredElementCount||(this._getWindow().removeEventListener(`focus`,this._windowFocusListener),this._stopInputModalityDetector.next(),clearTimeout(this._windowFocusTimeoutId),clearTimeout(this._originTimeoutId))}_originChanged(e,t,n){this._setClasses(e,t),this._emitOrigin(n,t),this._lastFocusOrigin=t}_getClosestElementsInfo(e){let t=[];return this._elementInfo.forEach((n,r)=>{(r===e||n.checkChildren&&r.contains(e))&&t.push([r,n])}),t}_isLastInteractionFromInputLabel(e){let{_mostRecentTarget:t,mostRecentModality:n}=this._inputModalityDetector;if(n!==`mouse`||!t||t===e||e.nodeName!==`INPUT`&&e.nodeName!==`TEXTAREA`||e.disabled)return!1;let r=e.labels;if(r){for(let s=0;s<r.length;s++)if(r[s].contains(t))return!0}return!1}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var yt=new Set;var L;var xe=(()=>{class a{_platform=D(O);_nonce=D(Gg,{optional:!0});_matchMedia;constructor(){this._matchMedia=this._platform.isBrowser&&window.matchMedia?window.matchMedia.bind(window):Pt}matchMedia(e){return(this._platform.WEBKIT||this._platform.BLINK)&&Lt(e,this._nonce),this._matchMedia(e)}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();function Lt(a,i){if(!yt.has(a))try{L||(L=document.createElement(`style`),i&&L.setAttribute(`nonce`,i),L.setAttribute(`type`,`text/css`),document.head.appendChild(L)),L.sheet&&(L.sheet.insertRule(`@media ${a.replace(/[{}]/g,``)} {body{ }}`,0),yt.add(a))}catch(e){console.error(e)}}function Pt(a){return{matches:a===`all`||a===``,media:a,addListener:()=>{},removeListener:()=>{}}}function Bt(a){if(a.type===`characterData`&&a.target instanceof Comment)return!0;if(a.type===`childList`){for(let i=0;i<a.addedNodes.length;i++)if(!(a.addedNodes[i]instanceof Comment))return!1;for(let i=0;i<a.removedNodes.length;i++)if(!(a.removedNodes[i]instanceof Comment))return!1;return!0}return!1}var Ht=(()=>{class a{create(e){return typeof MutationObserver>`u`?null:new MutationObserver(e)}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var Ut=(()=>{class a{_mutationObserverFactory=D(Ht);_observedElements=new Map;_ngZone=D(Pe);ngOnDestroy(){this._observedElements.forEach((e,t)=>this._cleanupObserver(t))}observe(e){let t=Oe$1(e);return new T(n=>{let s=this._observeElement(t).pipe(pt$1(c=>c.filter(_=>!Bt(_))),En(c=>!!c.length)).subscribe(c=>{this._ngZone.run(()=>{n.next(c)})});return()=>{s.unsubscribe(),this._unobserveElement(t)}})}_observeElement(e){return this._ngZone.runOutsideAngular(()=>{if(this._observedElements.has(e))this._observedElements.get(e).count++;else{let t=new z,n=this._mutationObserverFactory.create(r=>t.next(r));n&&n.observe(e,{characterData:!0,childList:!0,subtree:!0}),this._observedElements.set(e,{observer:n,stream:t,count:1})}return this._observedElements.get(e).stream})}_unobserveElement(e){this._observedElements.has(e)&&(this._observedElements.get(e).count--,this._observedElements.get(e).count||this._cleanupObserver(e))}_cleanupObserver(e){if(this._observedElements.has(e)){let{observer:t,stream:n}=this._observedElements.get(e);t&&t.disconnect(),n.complete(),this._observedElements.delete(e)}}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var Tt=(()=>{class a{_contentObserver=D(Ut);_elementRef=D(nr);event=new Ke;get disabled(){return this._disabled}set disabled(e){this._disabled=e,this._disabled?this._unsubscribe():this._subscribe()}_disabled=!1;get debounce(){return this._debounce}set debounce(e){this._debounce=R(e),this._subscribe()}_debounce;_currentSubscription=null;ngAfterContentInit(){!this._currentSubscription&&!this.disabled&&this._subscribe()}ngOnDestroy(){this._unsubscribe()}_subscribe(){this._unsubscribe();let e=this._contentObserver.observe(this._elementRef);this._currentSubscription=(this.debounce?e.pipe(Wf(this.debounce)):e).subscribe(this.event)}_unsubscribe(){this._currentSubscription?.unsubscribe()}static ɵfac=function(t){return new(t||a)};static ɵdir=dS({type:a,selectors:[[``,`cdkObserveContent`,``]],inputs:{disabled:[2,`cdkObserveContentDisabled`,`disabled`,ZO],debounce:`debounce`},outputs:{event:`cdkObserveContent`},exportAs:[`cdkObserveContent`]})}return a})();var jt=200;var le=class{_letterKeyStream=new z;_items=[];_selectedItemIndex=-1;_pressedLetters=[];_skipPredicateFn;_selectedItem=new z;selectedItem=this._selectedItem;constructor(i,e){let t=typeof e?.debounceInterval==`number`?e.debounceInterval:jt;e?.skipPredicate&&(this._skipPredicateFn=e.skipPredicate),this.setItems(i),this._setupKeyHandler(t)}destroy(){this._pressedLetters=[],this._letterKeyStream.complete(),this._selectedItem.complete()}setCurrentSelectedItemIndex(i){this._selectedItemIndex=i}setItems(i){this._items=i}handleKey(i){let e=i.keyCode;i.key&&i.key.length===1?this._letterKeyStream.next(i.key.toLocaleUpperCase()):(e>=65&&e<=90||e>=48&&e<=57)&&this._letterKeyStream.next(String.fromCharCode(e))}isTyping(){return this._pressedLetters.length>0}reset(){this._pressedLetters=[]}_setupKeyHandler(i){this._letterKeyStream.pipe(ig(e=>this._pressedLetters.push(e)),Wf(i),En(()=>this._pressedLetters.length>0),pt$1(()=>this._pressedLetters.join(``).toLocaleUpperCase())).subscribe(e=>{for(let t=1;t<this._items.length+1;t++){let n=(this._selectedItemIndex+t)%this._items.length,r=this._items[n];if(!this._skipPredicateFn?.(r)&&r.getLabel?.().toLocaleUpperCase().trim().indexOf(e)===0){this._selectedItem.next(r);break}}this._pressedLetters=[]})}};function me(a,...i){return i.length?i.some(e=>a[e]):a.altKey||a.shiftKey||a.ctrlKey||a.metaKey}var be=class{_items;_activeItemIndex=Eo(-1);_activeItem=Eo(null);_wrap=!1;_typeaheadSubscription=_.EMPTY;_itemChangesSubscription;_vertical=!0;_horizontal=null;_allowedModifierKeys=[];_homeAndEnd=!1;_pageUpAndDown={enabled:!1,delta:10};_effectRef;_typeahead;_skipPredicateFn=i=>i.disabled;constructor(i,e){this._items=i,i instanceof No?this._itemChangesSubscription=i.changes.subscribe(t=>this._itemsChanged(t.toArray())):_s(i)&&(this._effectRef=hu(()=>this._itemsChanged(i()),{injector:e}))}tabOut=new z;change=new z;skipPredicate(i){return this._skipPredicateFn=i,this}withWrap(i=!0){return this._wrap=i,this}withVerticalOrientation(i=!0){return this._vertical=i,this}withHorizontalOrientation(i){return this._horizontal=i,this}withAllowedModifierKeys(i){return this._allowedModifierKeys=i,this}withTypeAhead(i=200){this._typeaheadSubscription.unsubscribe();let e=this._getItemsArray();return this._typeahead=new le(e,{debounceInterval:typeof i==`number`?i:void 0,skipPredicate:t=>this._skipPredicateFn(t)}),this._typeaheadSubscription=this._typeahead.selectedItem.subscribe(t=>{this.setActiveItem(t)}),this}cancelTypeahead(){return this._typeahead?.reset(),this}withHomeAndEnd(i=!0){return this._homeAndEnd=i,this}withPageUpDown(i=!0,e=10){return this._pageUpAndDown={enabled:i,delta:e},this}setActiveItem(i){let e=this._activeItem();this.updateActiveItem(i),this._activeItem()!==e&&this.change.next(this._activeItemIndex())}onKeydown(i){let e=i.keyCode,n=[`altKey`,`ctrlKey`,`metaKey`,`shiftKey`].every(r=>!i[r]||this._allowedModifierKeys.indexOf(r)>-1);switch(e){case 9:this.tabOut.next();return;case 40:if(this._vertical&&n){this.setNextItemActive();break}else return;case 38:if(this._vertical&&n){this.setPreviousItemActive();break}else return;case 39:if(this._horizontal&&n){this._horizontal===`rtl`?this.setPreviousItemActive():this.setNextItemActive();break}else return;case 37:if(this._horizontal&&n){this._horizontal===`rtl`?this.setNextItemActive():this.setPreviousItemActive();break}else return;case 36:if(this._homeAndEnd&&n){this.setFirstItemActive();break}else return;case 35:if(this._homeAndEnd&&n){this.setLastItemActive();break}else return;case 33:if(this._pageUpAndDown.enabled&&n){let r=this._activeItemIndex()-this._pageUpAndDown.delta;this._setActiveItemByIndex(r>0?r:0,1);break}else return;case 34:if(this._pageUpAndDown.enabled&&n){let r=this._activeItemIndex()+this._pageUpAndDown.delta,s=this._getItemsArray().length;this._setActiveItemByIndex(r<s?r:s-1,-1);break}else return;default:(n||me(i,`shiftKey`))&&this._typeahead?.handleKey(i);return}this._typeahead?.reset(),i.preventDefault()}get activeItemIndex(){return this._activeItemIndex()}get activeItem(){return this._activeItem()}isTyping(){return!!this._typeahead&&this._typeahead.isTyping()}setFirstItemActive(){this._setActiveItemByIndex(0,1)}setLastItemActive(){this._setActiveItemByIndex(this._getItemsArray().length-1,-1)}setNextItemActive(){this._activeItemIndex()<0?this.setFirstItemActive():this._setActiveItemByDelta(1)}setPreviousItemActive(){this._activeItemIndex()<0&&this._wrap?this.setLastItemActive():this._setActiveItemByDelta(-1)}updateActiveItem(i){let e=this._getItemsArray(),t=typeof i==`number`?i:e.indexOf(i),n=e[t];this._activeItem.set(n??null),this._activeItemIndex.set(t),this._typeahead?.setCurrentSelectedItemIndex(t)}destroy(){this._typeaheadSubscription.unsubscribe(),this._itemChangesSubscription?.unsubscribe(),this._effectRef?.destroy(),this._typeahead?.destroy(),this.tabOut.complete(),this.change.complete()}_setActiveItemByDelta(i){this._wrap?this._setActiveInWrapMode(i):this._setActiveInDefaultMode(i)}_setActiveInWrapMode(i){let e=this._getItemsArray();for(let t=1;t<=e.length;t++){let n=(this._activeItemIndex()+i*t+e.length)%e.length,r=e[n];if(!this._skipPredicateFn(r)){this.setActiveItem(n);return}}}_setActiveInDefaultMode(i){this._setActiveItemByIndex(this._activeItemIndex()+i,i)}_setActiveItemByIndex(i,e){let t=this._getItemsArray();if(t[i]){for(;this._skipPredicateFn(t[i]);)if(i+=e,!t[i])return;this.setActiveItem(i)}}_getItemsArray(){return _s(this._items)?this._items():this._items instanceof No?this._items.toArray():this._items}_itemsChanged(i){this._typeahead?.setItems(i);let e=this._activeItem();if(e){let t=i.indexOf(e);t>-1&&t!==this._activeItemIndex()&&(this._activeItemIndex.set(t),this._typeahead?.setCurrentSelectedItemIndex(t))}}};var $=class extends be{_origin=`program`;setFocusOrigin(i){return this._origin=i,this}setActiveItem(i){super.setActiveItem(i),this.activeItem&&this.activeItem.focus(this._origin)}};var It=new Map;var j=class a{_appId=D(gu);static _infix=`a${Math.floor(Math.random()*1e5).toString()}`;getId(i,e=!1){this._appId!==`ng`&&(i+=this._appId);let t=It.get(i);return t===void 0?t=0:t++,It.set(i,t),`${i}${e?a._infix+`-`:``}${t}`}static ɵfac=function(e){return new(e||a)};static ɵprov=tr({token:a,factory:a.ɵfac})};var Se=class{_box;_destroyed=new z;_resizeSubject=new z;_resizeObserver;_elementObservables=new Map;constructor(i){this._box=i,typeof ResizeObserver<`u`&&(this._resizeObserver=new ResizeObserver(e=>this._resizeSubject.next(e)))}observe(i){return this._elementObservables.has(i)||this._elementObservables.set(i,new T(e=>{let t=this._resizeSubject.subscribe(e);return this._resizeObserver?.observe(i,{box:this._box}),()=>{this._resizeObserver?.unobserve(i),t.unsubscribe(),this._elementObservables.delete(i)}}).pipe(En(e=>e.some(t=>t.target===i)),eg({bufferSize:1,refCount:!0}),og(this._destroyed))),this._elementObservables.get(i)}destroy(){this._destroyed.next(),this._destroyed.complete(),this._resizeSubject.complete(),this._elementObservables.clear()}};var Ct=(()=>{class a{_cleanupErrorListener;_observers=new Map;_ngZone=D(Pe);constructor(){}ngOnDestroy(){for(let[,e]of this._observers)e.destroy();this._observers.clear(),this._cleanupErrorListener?.()}observe(e,t){let n=t?.box||`content-box`;return this._observers.has(n)||this._observers.set(n,new Se(n)),this._observers.get(n).observe(e)}static ɵfac=function(t){return new(t||a)};static ɵprov=tr({token:a,factory:a.ɵfac})}return a})();var Vt=new k(`MATERIAL_ANIMATIONS`);var kt=null;function Wt(){return D(Vt,{optional:!0})?.animationsDisabled||D(Ug,{optional:!0})===`NoopAnimations`?`di-disabled`:(kt??=D(xe).matchMedia(`(prefers-reduced-motion)`).matches,kt?`reduced-motion`:`enabled`)}function Z(){return Wt()!==`enabled`}var p=(function(a){return a[a.FADING_IN=0]=`FADING_IN`,a[a.VISIBLE=1]=`VISIBLE`,a[a.FADING_OUT=2]=`FADING_OUT`,a[a.HIDDEN=3]=`HIDDEN`,a})(p||{});var Me=class{_renderer;element;config;_animationForciblyDisabledThroughCss;state=p.HIDDEN;constructor(i,e,t,n=!1){this._renderer=i,this.element=e,this.config=t,this._animationForciblyDisabledThroughCss=n}fadeOut(){this._renderer.fadeOutRipple(this)}};var wt=U({passive:!0,capture:!0});var De=class{_events=new Map;addHandler(i,e,t,n){let r=this._events.get(e);if(r){let s=r.get(t);s?s.add(n):r.set(t,new Set([n]))}else this._events.set(e,new Map([[t,new Set([n])]])),i.runOutsideAngular(()=>{document.addEventListener(e,this._delegateEventHandler,wt)})}removeHandler(i,e,t){let n=this._events.get(i);if(!n)return;let r=n.get(e);r&&(r.delete(t),r.size===0&&n.delete(e),n.size===0&&(this._events.delete(i),document.removeEventListener(i,this._delegateEventHandler,wt)))}_delegateEventHandler=i=>{let e=I(i);e&&this._events.get(i.type)?.forEach((t,n)=>{(n===e||n.contains(e))&&t.forEach(r=>r.handleEvent(i))})}};var Et={enterDuration:225,exitDuration:150};var Kt=800;var xt=U({passive:!0,capture:!0});var St=[`mousedown`,`touchstart`];var Mt=[`mouseup`,`mouseleave`,`touchend`,`touchcancel`];var Gt=(()=>{class a{static ɵfac=function(t){return new(t||a)};static ɵcmp=aS({type:a,selectors:[[`ng-component`]],hostAttrs:[`mat-ripple-style-loader`,``],decls:0,vars:0,template:function(t,n){},styles:[`.mat-ripple {
  overflow: hidden;
  position: relative;
}
.mat-ripple:not(:empty) {
  transform: translateZ(0);
}

.mat-ripple.mat-ripple-unbounded {
  overflow: visible;
}

.mat-ripple-element {
  position: absolute;
  border-radius: 50%;
  pointer-events: none;
  transition: opacity, transform 0ms cubic-bezier(0, 0, 0.2, 1);
  transform: scale3d(0, 0, 0);
  background-color: var(--%NS%mat-ripple-color, color-mix(in srgb, var(--%NS%mat-sys-on-surface) 10%, transparent));
}
@media (forced-colors: active) {
  .mat-ripple-element {
    display: none;
  }
}
.cdk-drag-preview .mat-ripple-element, .cdk-drag-placeholder .mat-ripple-element {
  display: none;
}
`],encapsulation:2})}return a})();var Ae=class a{_target;_ngZone;_platform;_containerElement;_triggerElement=null;_isPointerDown=!1;_activeRipples=new Map;_mostRecentTransientRipple=null;_lastTouchStartEvent;_pointerUpEventsRegistered=!1;_containerRect=null;static _eventManager=new De;constructor(i,e,t,n,r){this._target=i,this._ngZone=e,this._platform=n,n.isBrowser&&(this._containerElement=Oe$1(t)),r&&r.get(V).load(Gt)}fadeInRipple(i,e,t={}){let n=this._containerRect=this._containerRect||this._containerElement.getBoundingClientRect(),r=j$1(j$1({},Et),t.animation);t.centered&&(i=n.left+n.width/2,e=n.top+n.height/2);let s=t.radius||Qt(i,e,n),c=i-n.left,_=e-n.top,C=r.enterDuration,l=document.createElement(`div`);l.classList.add(`mat-ripple-element`),l.style.left=`${c-s}px`,l.style.top=`${_-s}px`,l.style.height=`${s*2}px`,l.style.width=`${s*2}px`,t.color!=null&&(l.style.backgroundColor=t.color),l.style.transitionDuration=`${C}ms`,this._containerElement.appendChild(l);let Be=window.getComputedStyle(l),Rt=Be.transitionProperty,He=Be.transitionDuration,he=Rt===`none`||He===`0s`||He===`0s, 0s`||n.width===0&&n.height===0,S=new Me(this,l,t,he);l.style.transform=`scale3d(1, 1, 1)`,S.state=p.FADING_IN,t.persistent||(this._mostRecentTransientRipple=S);let Y=null;return!he&&(C||r.exitDuration)&&this._ngZone.runOutsideAngular(()=>{let Ue=()=>{Y&&(Y.fallbackTimer=null),clearTimeout(je),this._finishRippleTransition(S)},ue=()=>this._destroyRipple(S),je=setTimeout(ue,C+100);l.addEventListener(`transitionend`,Ue),l.addEventListener(`transitioncancel`,ue),Y={onTransitionEnd:Ue,onTransitionCancel:ue,fallbackTimer:je}}),this._activeRipples.set(S,Y),(he||!C)&&this._finishRippleTransition(S),S}fadeOutRipple(i){if(i.state===p.FADING_OUT||i.state===p.HIDDEN)return;let e=i.element,t=j$1(j$1({},Et),i.config.animation);e.style.transitionDuration=`${t.exitDuration}ms`,e.style.opacity=`0`,i.state=p.FADING_OUT,(i._animationForciblyDisabledThroughCss||!t.exitDuration)&&this._finishRippleTransition(i)}fadeOutAll(){this._getActiveRipples().forEach(i=>i.fadeOut())}fadeOutAllNonPersistent(){this._getActiveRipples().forEach(i=>{i.config.persistent||i.fadeOut()})}setupTriggerEvents(i){let e=Oe$1(i);!this._platform.isBrowser||!e||e===this._triggerElement||(this._removeTriggerEvents(),this._triggerElement=e,St.forEach(t=>{a._eventManager.addHandler(this._ngZone,t,e,this)}))}handleEvent(i){i.type===`mousedown`?this._onMousedown(i):i.type===`touchstart`?this._onTouchStart(i):this._onPointerUp(),this._pointerUpEventsRegistered||(this._ngZone.runOutsideAngular(()=>{Mt.forEach(e=>{this._triggerElement.addEventListener(e,this,xt)})}),this._pointerUpEventsRegistered=!0)}_finishRippleTransition(i){i.state===p.FADING_IN?this._startFadeOutTransition(i):i.state===p.FADING_OUT&&this._destroyRipple(i)}_startFadeOutTransition(i){let e=i===this._mostRecentTransientRipple,{persistent:t}=i.config;i.state=p.VISIBLE,!t&&(!e||!this._isPointerDown)&&i.fadeOut()}_destroyRipple(i){let e=this._activeRipples.get(i)??null;this._activeRipples.delete(i),this._activeRipples.size||(this._containerRect=null),i===this._mostRecentTransientRipple&&(this._mostRecentTransientRipple=null),i.state=p.HIDDEN,e!==null&&(i.element.removeEventListener(`transitionend`,e.onTransitionEnd),i.element.removeEventListener(`transitioncancel`,e.onTransitionCancel),e.fallbackTimer!==null&&clearTimeout(e.fallbackTimer)),i.element.remove()}_onMousedown(i){let e=W(i),t=this._lastTouchStartEvent&&Date.now()<this._lastTouchStartEvent+Kt;!this._target.rippleDisabled&&!e&&!t&&(this._isPointerDown=!0,this.fadeInRipple(i.clientX,i.clientY,this._target.rippleConfig))}_onTouchStart(i){if(!this._target.rippleDisabled&&!K(i)){this._lastTouchStartEvent=Date.now(),this._isPointerDown=!0;let e=i.changedTouches;if(e)for(let t=0;t<e.length;t++)this.fadeInRipple(e[t].clientX,e[t].clientY,this._target.rippleConfig)}}_onPointerUp(){this._isPointerDown&&(this._isPointerDown=!1,this._getActiveRipples().forEach(i=>{let e=i.state===p.VISIBLE||i.config.terminateOnPointerUp&&i.state===p.FADING_IN;!i.config.persistent&&e&&i.fadeOut()}))}_getActiveRipples(){return Array.from(this._activeRipples.keys())}_removeTriggerEvents(){let i=this._triggerElement;i&&(St.forEach(e=>a._eventManager.removeHandler(e,i,this)),this._pointerUpEventsRegistered&&(Mt.forEach(e=>i.removeEventListener(e,this,xt)),this._pointerUpEventsRegistered=!1))}};function Qt(a,i,e){let t=Math.max(Math.abs(a-e.left),Math.abs(a-e.right)),n=Math.max(Math.abs(i-e.top),Math.abs(i-e.bottom));return Math.sqrt(t*t+n*n)}var Ne=new k(`mat-ripple-global-options`);var Re=(()=>{class a{_elementRef=D(nr);_animationsDisabled=Z();color;unbounded=!1;centered=!1;radius=0;animation;get disabled(){return this._disabled}set disabled(e){e&&this.fadeOutAllNonPersistent(),this._disabled=e,this._setupTriggerEventsIfEnabled()}_disabled=!1;get trigger(){return this._trigger||this._elementRef.nativeElement}set trigger(e){this._trigger=e,this._setupTriggerEventsIfEnabled()}_trigger;_rippleRenderer;_globalOptions;_isInitialized=!1;constructor(){let e=D(Pe),t=D(O),n=D(Ne,{optional:!0}),r=D(oe);this._globalOptions=n||{},this._rippleRenderer=new Ae(this,e,this._elementRef,t,r)}ngOnInit(){this._isInitialized=!0,this._setupTriggerEventsIfEnabled()}ngOnDestroy(){this._rippleRenderer._removeTriggerEvents()}fadeOutAll(){this._rippleRenderer.fadeOutAll()}fadeOutAllNonPersistent(){this._rippleRenderer.fadeOutAllNonPersistent()}get rippleConfig(){return{centered:this.centered,radius:this.radius,color:this.color,animation:j$1(j$1(j$1({},this._globalOptions.animation),this._animationsDisabled?{enterDuration:0,exitDuration:0}:{}),this.animation),terminateOnPointerUp:this._globalOptions.terminateOnPointerUp}}get rippleDisabled(){return this.disabled||!!this._globalOptions.disabled}_setupTriggerEventsIfEnabled(){!this.disabled&&this._isInitialized&&this._rippleRenderer.setupTriggerEvents(this.trigger)}launch(e,t=0,n){return typeof e==`number`?this._rippleRenderer.fadeInRipple(e,t,j$1(j$1({},this.rippleConfig),n)):this._rippleRenderer.fadeInRipple(0,0,j$1(j$1({},this.rippleConfig),e))}static ɵfac=function(t){return new(t||a)};static ɵdir=dS({type:a,selectors:[[``,`mat-ripple`,``],[``,`matRipple`,``]],hostAttrs:[1,`mat-ripple`],hostVars:2,hostBindings:function(t,n){t&2&&um(`mat-ripple-unbounded`,n.unbounded)},inputs:{color:[0,`matRippleColor`,`color`],unbounded:[0,`matRippleUnbounded`,`unbounded`],centered:[0,`matRippleCentered`,`centered`],radius:[0,`matRippleRadius`,`radius`],animation:[0,`matRippleAnimation`,`animation`],disabled:[0,`matRippleDisabled`,`disabled`],trigger:[0,`matRippleTrigger`,`trigger`]},exportAs:[`matRipple`]})}return a})();var Fe=[`*`];var $t=[`tabListContainer`];var Zt=[`tabList`];var Yt=[`tabListInner`];var qt=[`nextPaginator`];var Xt=[`previousPaginator`];var Le=`mdc-tab-indicator--active`;var Dt=`mdc-tab-indicator--no-transition`;var Oe=class{_items;_currentItem;constructor(i){this._items=i}hide(){this._items.forEach(i=>i.deactivateInkBar()),this._currentItem=void 0}alignToElement(i){let e=this._items.find(n=>n.elementRef.nativeElement===i),t=this._currentItem;if(e!==t&&(t?.deactivateInkBar(),e)){let n=t?.elementRef.nativeElement.getBoundingClientRect?.();e.activateInkBar(n),this._currentItem=e}}};var Jt=(()=>{class a{_elementRef=D(nr);_inkBarElement=null;_inkBarContentElement=null;_fitToContent=!1;get fitInkBarToContent(){return this._fitToContent}set fitInkBarToContent(e){this._fitToContent!==e&&(this._fitToContent=e,this._inkBarElement&&this._appendInkBarElement())}activateInkBar(e){let t=this._elementRef.nativeElement;if(!e||!t.getBoundingClientRect||!this._inkBarContentElement){t.classList.add(Le);return}let n=t.getBoundingClientRect(),r=e.width/n.width,s=e.left-n.left;t.classList.add(Dt),this._inkBarContentElement.style.setProperty(`transform`,`translateX(${s}px) scaleX(${r})`),t.getBoundingClientRect(),t.classList.remove(Dt),t.classList.add(Le),this._inkBarContentElement.style.setProperty(`transform`,``)}deactivateInkBar(){this._elementRef.nativeElement.classList.remove(Le)}ngOnInit(){this._createInkBarElement()}ngOnDestroy(){this._inkBarElement?.remove(),this._inkBarElement=this._inkBarContentElement=null}_createInkBarElement(){let e=this._elementRef.nativeElement.ownerDocument||document,t=this._inkBarElement=e.createElement(`span`),n=this._inkBarContentElement=e.createElement(`span`);t.className=`mdc-tab-indicator`,n.className=`mdc-tab-indicator__content mdc-tab-indicator__content--underline`,t.appendChild(this._inkBarContentElement),this._appendInkBarElement()}_appendInkBarElement(){this._inkBarElement;(this._fitToContent?this._elementRef.nativeElement.querySelector(`.mdc-tab__content`):this._elementRef.nativeElement).appendChild(this._inkBarElement)}static ɵfac=function(t){return new(t||a)};static ɵdir=dS({type:a,inputs:{fitInkBarToContent:[2,`fitInkBarToContent`,`fitInkBarToContent`,ZO]}})}return a})();var At={passive:!0};var en=650;var tn=100;function nn(a){let i=a+``;return/^[0-9]+(?:\.[0-9]+)?$/.test(i)?`${a}ms`:/^[0-9]+(?:\.[0-9]+)?(?:ms|s)$/.test(i)?i:``}var an=(()=>{class a{_elementRef=D(nr);_changeDetectorRef=D(YO);_viewportRuler=D($e);_dir=D(j$2,{optional:!0});_ngZone=D(Pe);_platform=D(O);_sharedResizeObserver=D(Ct);_injector=D(oe);_renderer=D(ia);_animationsDisabled=Z();_eventCleanups;_scrollDistance=0;_selectedIndexChanged=!1;_destroyed=new z;_showPaginationControls=!1;_disableScrollAfter=!0;_disableScrollBefore=!0;_tabLabelCount;_scrollDistanceChanged=!1;_keyManager;_currentTextContent;_stopScrolling=new z;disablePagination=!1;get selectedIndex(){return this._selectedIndex}set selectedIndex(e){let t=isNaN(e)?0:e;this._selectedIndex!=t&&(this._selectedIndexChanged=!0,this._selectedIndex=t,this._keyManager&&this._keyManager.updateActiveItem(t))}_selectedIndex=0;selectFocusedIndex=new Ke;indexFocused=new Ke;constructor(){this._eventCleanups=this._ngZone.runOutsideAngular(()=>[this._renderer.listen(this._elementRef.nativeElement,`mouseleave`,()=>this._stopInterval())])}ngAfterViewInit(){this._eventCleanups.push(this._renderer.listen(this._previousPaginator.nativeElement,`touchstart`,()=>this._handlePaginatorPress(`before`),At),this._renderer.listen(this._nextPaginator.nativeElement,`touchstart`,()=>this._handlePaginatorPress(`after`),At))}ngAfterContentInit(){let e=this._dir?this._dir.change:kf(`ltr`),t=this._sharedResizeObserver.observe(this._elementRef.nativeElement).pipe(Wf(32),og(this._destroyed)),n=this._viewportRuler.change(150).pipe(og(this._destroyed)),r=()=>{this.updatePagination(),this._alignInkBarToSelectedTab()};this._keyManager=new $(this._items).withHorizontalOrientation(this._getLayoutDirection()).withHomeAndEnd().withWrap().skipPredicate(()=>!1),this._keyManager.updateActiveItem(Math.max(this._selectedIndex,0)),mh(r,{injector:this._injector}),jf(e,n,t,this._items.changes,this._itemsResized()).pipe(og(this._destroyed)).subscribe(()=>{this._ngZone.run(()=>{Promise.resolve().then(()=>{this._scrollDistance=Math.max(0,Math.min(this._getMaxScrollDistance(),this._scrollDistance)),r()})}),this._keyManager?.withHorizontalOrientation(this._getLayoutDirection())}),this._keyManager.change.subscribe(s=>{this.indexFocused.emit(s),this._setTabFocus(s)})}_itemsResized(){return typeof ResizeObserver!=`function`?ut$1:this._items.changes.pipe(ng(this._items),rg(e=>new T(t=>this._ngZone.runOutsideAngular(()=>{let n=new ResizeObserver(r=>t.next(r));return e.forEach(r=>n.observe(r.elementRef.nativeElement)),()=>{n.disconnect()}}))),tg(1),En(e=>e.some(t=>t.contentRect.width>0&&t.contentRect.height>0)))}ngAfterContentChecked(){this._tabLabelCount!=this._items.length&&(this.updatePagination(),this._tabLabelCount=this._items.length,this._changeDetectorRef.markForCheck()),this._selectedIndexChanged&&(this._scrollToLabel(this._selectedIndex),this._checkScrollingControls(),this._alignInkBarToSelectedTab(),this._selectedIndexChanged=!1,this._changeDetectorRef.markForCheck()),this._scrollDistanceChanged&&(this._updateTabScrollPosition(),this._scrollDistanceChanged=!1,this._changeDetectorRef.markForCheck())}ngOnDestroy(){this._eventCleanups.forEach(e=>e()),this._keyManager?.destroy(),this._destroyed.next(),this._destroyed.complete(),this._stopScrolling.complete()}_handleKeydown(e){if(!me(e))switch(e.keyCode){case 13:case 32:if(this.focusIndex!==this.selectedIndex){let t=this._items.get(this.focusIndex);t&&!t.disabled&&(this.selectFocusedIndex.emit(this.focusIndex),this._itemSelected(e))}break;default:this._keyManager?.onKeydown(e)}}_onContentChanges(){let e=this._elementRef.nativeElement.textContent;e!==this._currentTextContent&&(this._currentTextContent=e||``,this._ngZone.run(()=>{this.updatePagination(),this._alignInkBarToSelectedTab(),this._changeDetectorRef.markForCheck()}))}updatePagination(){this._checkPaginationEnabled(),this._checkScrollingControls(),this._updateTabScrollPosition()}get focusIndex(){return this._keyManager?this._keyManager.activeItemIndex:0}set focusIndex(e){!this._isValidIndex(e)||this.focusIndex===e||!this._keyManager||this._keyManager.setActiveItem(e)}_isValidIndex(e){return this._items?!!this._items.toArray()[e]:!0}_setTabFocus(e){if(this._showPaginationControls&&this._scrollToLabel(e),this._items&&this._items.length){this._items.toArray()[e].focus();let t=this._tabListContainer.nativeElement;this._getLayoutDirection()==`ltr`?t.scrollLeft=0:t.scrollLeft=t.scrollWidth-t.offsetWidth}}_getLayoutDirection(){return this._dir&&this._dir.value===`rtl`?`rtl`:`ltr`}_updateTabScrollPosition(){if(this.disablePagination)return;let e=this.scrollDistance,t=this._getLayoutDirection()===`ltr`?-e:e;this._tabList.nativeElement.style.transform=`translateX(${Math.round(t)}px)`,(this._platform.TRIDENT||this._platform.EDGE)&&(this._tabListContainer.nativeElement.scrollLeft=0)}get scrollDistance(){return this._scrollDistance}set scrollDistance(e){this._scrollTo(e)}_scrollHeader(e){let t=this._tabListContainer.nativeElement.offsetWidth,n=(e==`before`?-1:1)*t/3;return this._scrollTo(this._scrollDistance+n)}_handlePaginatorClick(e){this._stopInterval(),this._scrollHeader(e)}_scrollToLabel(e){if(this.disablePagination)return;let t=this._items?this._items.toArray()[e]:null;if(!t)return;let n=this._tabListContainer.nativeElement.offsetWidth,{offsetLeft:r,offsetWidth:s}=t.elementRef.nativeElement,c,_;this._getLayoutDirection()==`ltr`?(c=r,_=c+s):(_=this._tabListInner.nativeElement.offsetWidth-r,c=_-s);let C=this.scrollDistance,l=this.scrollDistance+n;c<C?this.scrollDistance-=C-c:_>l&&(this.scrollDistance+=Math.min(_-l,c-C))}_checkPaginationEnabled(){if(this.disablePagination)this._showPaginationControls=!1;else{let n=this._tabListInner.nativeElement.scrollWidth-this._elementRef.nativeElement.offsetWidth>=5;n||(this.scrollDistance=0),n!==this._showPaginationControls&&(this._showPaginationControls=n,this._changeDetectorRef.markForCheck())}}_checkScrollingControls(){this.disablePagination?this._disableScrollAfter=this._disableScrollBefore=!0:(this._disableScrollBefore=this.scrollDistance==0,this._disableScrollAfter=this.scrollDistance==this._getMaxScrollDistance(),this._changeDetectorRef.markForCheck())}_getMaxScrollDistance(){return this._tabListInner.nativeElement.scrollWidth-this._tabListContainer.nativeElement.offsetWidth||0}_alignInkBarToSelectedTab(){let e=this._items&&this._items.length?this._items.toArray()[this.selectedIndex]:null,t=e?e.elementRef.nativeElement:null;t?this._inkBar.alignToElement(t):this._inkBar.hide()}_stopInterval(){this._stopScrolling.next()}_handlePaginatorPress(e,t){t&&t.button!=null&&t.button!==0||(this._stopInterval(),Mi(en,tn).pipe(og(jf(this._stopScrolling,this._destroyed))).subscribe(()=>{let{maxScrollDistance:n,distance:r}=this._scrollHeader(e);(r===0||r>=n)&&this._stopInterval()}))}_scrollTo(e){if(this.disablePagination)return{maxScrollDistance:0,distance:0};let t=this._getMaxScrollDistance();return this._scrollDistance=Math.max(0,Math.min(t,e)),this._scrollDistanceChanged=!0,this._checkScrollingControls(),{maxScrollDistance:t,distance:this._scrollDistance}}static ɵfac=function(t){return new(t||a)};static ɵdir=dS({type:a,inputs:{disablePagination:[2,`disablePagination`,`disablePagination`,ZO],selectedIndex:[2,`selectedIndex`,`selectedIndex`,XO]},outputs:{selectFocusedIndex:`selectFocusedIndex`,indexFocused:`indexFocused`}})}return a})();var rn=new k(`MAT_TABS_CONFIG`);var on=(()=>{class a extends an{_focusedItem=Eo(null);get fitInkBarToContent(){return this._fitInkBarToContent.value}set fitInkBarToContent(e){this._fitInkBarToContent.next(e),this._changeDetectorRef.markForCheck()}_fitInkBarToContent=new gn(!1);stretchTabs=!0;animationDuration=``;_items;get backgroundColor(){return this._backgroundColor}set backgroundColor(e){let t=this._elementRef.nativeElement.classList;t.remove(`mat-tabs-with-background`,`mat-background-${this.backgroundColor}`),e&&t.add(`mat-tabs-with-background`,`mat-background-${e}`),this._backgroundColor=e}_backgroundColor;get disableRipple(){return this._disableRipple()}set disableRipple(e){this._disableRipple.set(e)}_disableRipple=Eo(!1);color=`primary`;tabPanel;_tabListContainer;_tabList;_tabListInner;_nextPaginator;_previousPaginator;_inkBar;constructor(){let e=D(rn,{optional:!0});super(),this.disablePagination=e&&e.disablePagination!=null?e.disablePagination:!1,this.fitInkBarToContent=e&&e.fitInkBarToContent!=null?e.fitInkBarToContent:!1,this.stretchTabs=e&&e.stretchTabs!=null?e.stretchTabs:!0}_itemSelected(){}ngAfterContentInit(){this._inkBar=new Oe(this._items),this._items.changes.pipe(ng(null),og(this._destroyed)).subscribe(()=>this.updateActiveLink()),super.ngAfterContentInit(),this._keyManager.change.pipe(ng(null),og(this._destroyed)).subscribe(()=>this._focusedItem.set(this._keyManager?.activeItem||null))}ngAfterViewInit(){this.tabPanel,super.ngAfterViewInit()}updateActiveLink(){if(!this._items)return;let e=this._items.toArray();for(let t=0;t<e.length;t++)if(e[t].active){this.selectedIndex=t,this.tabPanel&&(this.tabPanel._activeTabId=e[t].id),this._focusedItem.set(e[t]),this._changeDetectorRef.markForCheck();return}this.selectedIndex=-1}_getRole(){return this.tabPanel?`tablist`:this._elementRef.nativeElement.getAttribute(`role`)}_hasFocus(e){return this._keyManager?.activeItem===e}static ɵfac=function(t){return new(t||a)};static ɵcmp=aS({type:a,selectors:[[``,`mat-tab-nav-bar`,``]],contentQueries:function(t,n,r){if(t&1&&rm(r,sn,5),t&2){let s;HS(s=WS())&&(n._items=s)}},viewQuery:function(t,n){if(t&1&&om($t,7)(Zt,7)(Yt,7)(qt,5)(Xt,5),t&2){let r;HS(r=WS())&&(n._tabListContainer=r.first),HS(r=WS())&&(n._tabList=r.first),HS(r=WS())&&(n._tabListInner=r.first),HS(r=WS())&&(n._nextPaginator=r.first),HS(r=WS())&&(n._previousPaginator=r.first)}},hostAttrs:[1,`mat-mdc-tab-nav-bar`,`mat-mdc-tab-header`],hostVars:17,hostBindings:function(t,n){t&2&&($p(`role`,n._getRole()),cm(`--%NS%mat-tab-header-animation-duration`,n.animationDuration),um(`mat-mdc-tab-header-pagination-controls-enabled`,n._showPaginationControls)(`mat-mdc-tab-header-rtl`,n._getLayoutDirection()==`rtl`)(`mat-mdc-tab-nav-bar-stretch-tabs`,n.stretchTabs)(`mat-primary`,n.color!==`warn`&&n.color!==`accent`)(`mat-accent`,n.color===`accent`)(`mat-warn`,n.color===`warn`)(`_mat-animation-noopable`,n._animationsDisabled))},inputs:{fitInkBarToContent:[2,`fitInkBarToContent`,`fitInkBarToContent`,ZO],stretchTabs:[2,`mat-stretch-tabs`,`stretchTabs`,ZO],animationDuration:[2,`animationDuration`,`animationDuration`,nn],backgroundColor:`backgroundColor`,disableRipple:[2,`disableRipple`,`disableRipple`,ZO],color:`color`,tabPanel:`tabPanel`},exportAs:[`matTabNavBar`,`matTabNav`],features:[Gp],ngContentSelectors:Fe,decls:13,vars:6,consts:[[`previousPaginator`,``],[`tabListContainer`,``],[`tabList`,``],[`tabListInner`,``],[`nextPaginator`,``],[`mat-ripple`,``,1,`mat-mdc-tab-header-pagination`,`mat-mdc-tab-header-pagination-before`,3,`click`,`mousedown`,`touchend`,`matRippleDisabled`],[1,`mat-mdc-tab-header-pagination-chevron`],[1,`mat-mdc-tab-link-container`,3,`keydown`],[1,`mat-mdc-tab-list`,3,`cdkObserveContent`],[1,`mat-mdc-tab-links`],[`mat-ripple`,``,1,`mat-mdc-tab-header-pagination`,`mat-mdc-tab-header-pagination-after`,3,`mousedown`,`click`,`touchend`,`matRippleDisabled`]],template:function(t,n){t&1&&(qS(),Vo(0,`div`,5,0),tm(`click`,function(){return n._handlePaginatorClick(`before`)})(`mousedown`,function(s){return n._handlePaginatorPress(`before`,s)})(`touchend`,function(){return n._stopInterval()}),Qp(2,`div`,6),Xa(),Vo(3,`div`,7,1),tm(`keydown`,function(s){return n._handleKeydown(s)}),Vo(5,`div`,8,2),tm(`cdkObserveContent`,function(){return n._onContentChanges()}),Vo(7,`div`,9,3),jS(9),Xa()()(),Vo(10,`div`,10,4),tm(`mousedown`,function(s){return n._handlePaginatorPress(`after`,s)})(`click`,function(){return n._handlePaginatorClick(`after`)})(`touchend`,function(){return n._stopInterval()}),Qp(12,`div`,6),Xa()),t&2&&(um(`mat-mdc-tab-header-pagination-disabled`,n._disableScrollBefore),zp(`matRippleDisabled`,n._disableScrollBefore||n.disableRipple),_h(10),um(`mat-mdc-tab-header-pagination-disabled`,n._disableScrollAfter),zp(`matRippleDisabled`,n._disableScrollAfter||n.disableRipple))},dependencies:[Re,Tt],styles:[`.mdc-tab {
  min-width: 90px;
  padding: 0 24px;
  display: flex;
  flex: 1 0 auto;
  justify-content: center;
  box-sizing: border-box;
  border: none;
  outline: none;
  text-align: center;
  white-space: nowrap;
  cursor: pointer;
  z-index: 1;
  touch-action: manipulation;
}

.mdc-tab__content {
  display: flex;
  align-items: center;
  justify-content: center;
  height: inherit;
  pointer-events: none;
}

.mdc-tab__text-label {
  transition: 150ms color linear;
  display: inline-block;
  line-height: 1;
  z-index: 2;
}

.mdc-tab--active .mdc-tab__text-label {
  transition-delay: 100ms;
}

._mat-animation-noopable .mdc-tab__text-label {
  transition: none;
}

.mdc-tab-indicator {
  display: flex;
  position: absolute;
  top: 0;
  left: 0;
  justify-content: center;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 1;
}

.mdc-tab-indicator__content {
  transition: var(--%NS%mat-tab-header-animation-duration, 250ms) transform cubic-bezier(0.4, 0, 0.2, 1);
  transform-origin: left;
  opacity: 0;
}

.mdc-tab-indicator__content--underline {
  align-self: flex-end;
  box-sizing: border-box;
  width: 100%;
  border-top-style: solid;
}

.mdc-tab-indicator--active .mdc-tab-indicator__content {
  opacity: 1;
}

._mat-animation-noopable .mdc-tab-indicator__content, .mdc-tab-indicator--no-transition .mdc-tab-indicator__content {
  transition: none;
}

.mat-mdc-tab-ripple.mat-mdc-tab-ripple {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  pointer-events: none;
}

.mat-mdc-tab-header {
  display: flex;
  overflow: hidden;
  position: relative;
  flex-shrink: 0;
}

.mdc-tab-indicator .mdc-tab-indicator__content {
  transition-duration: var(--%NS%mat-tab-header-animation-duration, 250ms);
}

.mat-mdc-tab-header-pagination {
  -webkit-user-select: none;
  user-select: none;
  position: relative;
  display: none;
  justify-content: center;
  align-items: center;
  min-width: 32px;
  cursor: pointer;
  z-index: 2;
  -webkit-tap-highlight-color: transparent;
  touch-action: none;
  box-sizing: content-box;
  outline: 0;
}
.mat-mdc-tab-header-pagination::-moz-focus-inner {
  border: 0;
}
.mat-mdc-tab-header-pagination .mat-ripple-element {
  opacity: 0.12;
  background-color: var(--%NS%mat-tab-inactive-ripple-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-header-pagination-controls-enabled .mat-mdc-tab-header-pagination {
  display: flex;
}

.mat-mdc-tab-header-pagination-before,
.mat-mdc-tab-header-rtl .mat-mdc-tab-header-pagination-after {
  padding-left: 4px;
}
.mat-mdc-tab-header-pagination-before .mat-mdc-tab-header-pagination-chevron,
.mat-mdc-tab-header-rtl .mat-mdc-tab-header-pagination-after .mat-mdc-tab-header-pagination-chevron {
  transform: rotate(-135deg);
}

.mat-mdc-tab-header-rtl .mat-mdc-tab-header-pagination-before,
.mat-mdc-tab-header-pagination-after {
  padding-right: 4px;
}
.mat-mdc-tab-header-rtl .mat-mdc-tab-header-pagination-before .mat-mdc-tab-header-pagination-chevron,
.mat-mdc-tab-header-pagination-after .mat-mdc-tab-header-pagination-chevron {
  transform: rotate(45deg);
}

.mat-mdc-tab-header-pagination-chevron {
  border-style: solid;
  border-width: 2px 2px 0 0;
  height: 8px;
  width: 8px;
  border-color: var(--%NS%mat-tab-pagination-icon-color, var(--%NS%mat-sys-on-surface));
}

.mat-mdc-tab-header-pagination-disabled {
  box-shadow: none;
  cursor: default;
  pointer-events: none;
}
.mat-mdc-tab-header-pagination-disabled .mat-mdc-tab-header-pagination-chevron {
  opacity: 0.4;
}

.mat-mdc-tab-list {
  flex-grow: 1;
  position: relative;
  transition: transform 500ms cubic-bezier(0.35, 0, 0.25, 1);
}
._mat-animation-noopable .mat-mdc-tab-list {
  transition: none;
}

.mat-mdc-tab-links {
  display: flex;
  flex: 1 0 auto;
}
[mat-align-tabs=center] > .mat-mdc-tab-link-container .mat-mdc-tab-links {
  justify-content: center;
}
[mat-align-tabs=end] > .mat-mdc-tab-link-container .mat-mdc-tab-links {
  justify-content: flex-end;
}
.cdk-drop-list .mat-mdc-tab-links, .mat-mdc-tab-links.cdk-drop-list {
  min-height: var(--%NS%mat-tab-container-height, 48px);
}

.mat-mdc-tab-link-container {
  display: flex;
  flex-grow: 1;
  overflow: hidden;
  z-index: 1;
  border-bottom-style: solid;
  border-bottom-width: var(--%NS%mat-tab-divider-height, 1px);
  border-bottom-color: var(--%NS%mat-tab-divider-color, var(--%NS%mat-sys-surface-variant));
}

.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination {
  background-color: var(--%NS%mat-tab-background-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background.mat-primary > .mat-mdc-tab-link-container .mat-mdc-tab-link .mdc-tab__text-label {
  color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background.mat-primary > .mat-mdc-tab-link-container .mdc-tab-indicator__content--underline {
  border-color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background:not(.mat-primary) > .mat-mdc-tab-link-container .mat-mdc-tab-link:not(.mdc-tab--active) .mdc-tab__text-label {
  color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background:not(.mat-primary) > .mat-mdc-tab-link-container .mat-mdc-tab-link:not(.mdc-tab--active) .mdc-tab-indicator__content--underline {
  border-color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container .mat-mdc-tab-header-pagination-chevron,
.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container .mat-focus-indicator::before, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination .mat-mdc-tab-header-pagination-chevron,
.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination .mat-focus-indicator::before {
  border-color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container .mat-ripple-element, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container .mdc-tab__ripple::before, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination .mat-ripple-element, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination .mdc-tab__ripple::before {
  background-color: var(--%NS%mat-tab-foreground-color);
}
.mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-link-container .mat-mdc-tab-header-pagination-chevron, .mat-mdc-tab-nav-bar.mat-tabs-with-background > .mat-mdc-tab-header-pagination .mat-mdc-tab-header-pagination-chevron {
  color: var(--%NS%mat-tab-foreground-color);
}
`],encapsulation:2,changeDetection:1})}return a})();var sn=(()=>{class a extends Jt{_tabNavBar=D(on);elementRef=D(nr);_focusMonitor=D(Ee);_destroyed=new z;_isActive=!1;_tabIndex=Lv(()=>this._tabNavBar._focusedItem()===this?this.tabIndex:-1);get active(){return this._isActive}set active(e){e!==this._isActive&&(this._isActive=e,this._tabNavBar.updateActiveLink())}disabled=!1;get disableRipple(){return this._disableRipple()}set disableRipple(e){this._disableRipple.set(e)}_disableRipple=Eo(!1);tabIndex=0;rippleConfig;get rippleDisabled(){return this.disabled||this.disableRipple||this._tabNavBar.disableRipple||!!this.rippleConfig.disabled}id=D(j).getId(`mat-tab-link-`);constructor(){super(),D(V).load(bt);let e=D(Ne,{optional:!0}),t=D(new Cm(`tabindex`),{optional:!0});this.rippleConfig=e||{},this.tabIndex=t==null?0:parseInt(t)||0,Z()&&(this.rippleConfig.animation={enterDuration:0,exitDuration:0}),this._tabNavBar._fitInkBarToContent.pipe(og(this._destroyed)).subscribe(n=>{this.fitInkBarToContent=n})}focus(){this.elementRef.nativeElement.focus()}ngAfterViewInit(){this._focusMonitor.monitor(this.elementRef)}ngOnDestroy(){this._destroyed.next(),this._destroyed.complete(),super.ngOnDestroy(),this._focusMonitor.stopMonitoring(this.elementRef)}_handleFocus(){this._tabNavBar.focusIndex=this._tabNavBar._items.toArray().indexOf(this)}_handleKeydown(e){(e.keyCode===32||e.keyCode===13)&&(this.disabled?e.preventDefault():this._tabNavBar.tabPanel&&(e.keyCode===32&&e.preventDefault(),this.elementRef.nativeElement.click()))}_getAriaControls(){return this._tabNavBar.tabPanel?this._tabNavBar.tabPanel?.id:this.elementRef.nativeElement.getAttribute(`aria-controls`)}_getAriaSelected(){return this._tabNavBar.tabPanel?this.active?`true`:`false`:this.elementRef.nativeElement.getAttribute(`aria-selected`)}_getAriaCurrent(){return this.active&&!this._tabNavBar.tabPanel?`page`:null}_getRole(){return this._tabNavBar.tabPanel?`tab`:this.elementRef.nativeElement.getAttribute(`role`)}static ɵfac=function(t){return new(t||a)};static ɵcmp=aS({type:a,selectors:[[``,`mat-tab-link`,``],[``,`matTabLink`,``]],hostAttrs:[1,`mdc-tab`,`mat-mdc-tab-link`,`mat-focus-indicator`],hostVars:11,hostBindings:function(t,n){t&1&&tm(`focus`,function(){return n._handleFocus()})(`keydown`,function(s){return n._handleKeydown(s)}),t&2&&($p(`aria-controls`,n._getAriaControls())(`aria-current`,n._getAriaCurrent())(`aria-disabled`,n.disabled)(`aria-selected`,n._getAriaSelected())(`id`,n.id)(`tabIndex`,n._tabIndex())(`role`,n._getRole()),um(`mat-mdc-tab-disabled`,n.disabled)(`mdc-tab--active`,n.active))},inputs:{active:[2,`active`,`active`,ZO],disabled:[2,`disabled`,`disabled`,ZO],disableRipple:[2,`disableRipple`,`disableRipple`,ZO],tabIndex:[2,`tabIndex`,`tabIndex`,e=>e==null?0:XO(e)],id:`id`},exportAs:[`matTabLink`],features:[Gp],ngContentSelectors:Fe,decls:5,vars:2,consts:[[1,`mdc-tab__ripple`],[`mat-ripple`,``,1,`mat-mdc-tab-ripple`,3,`matRippleTrigger`,`matRippleDisabled`],[1,`mdc-tab__content`],[1,`mdc-tab__text-label`]],template:function(t,n){t&1&&(qS(),Qp(0,`span`,0)(1,`div`,1),Vo(2,`span`,2)(3,`span`,3),jS(4),Xa()()),t&2&&(_h(),zp(`matRippleTrigger`,n.elementRef.nativeElement)(`matRippleDisabled`,n.rippleDisabled))},dependencies:[Re],styles:[`.mat-mdc-tab-link {
  -webkit-tap-highlight-color: transparent;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-decoration: none;
  background: none;
  height: var(--%NS%mat-tab-container-height, 48px);
  font-family: var(--%NS%mat-tab-label-text-font, var(--%NS%mat-sys-title-small-font));
  font-size: var(--%NS%mat-tab-label-text-size, var(--%NS%mat-sys-title-small-size));
  letter-spacing: var(--%NS%mat-tab-label-text-tracking, var(--%NS%mat-sys-title-small-tracking));
  line-height: var(--%NS%mat-tab-label-text-line-height, var(--%NS%mat-sys-title-small-line-height));
  font-weight: var(--%NS%mat-tab-label-text-weight, var(--%NS%mat-sys-title-small-weight));
}
.mat-mdc-tab-link.mdc-tab {
  flex-grow: 0;
}
.mat-mdc-tab-link .mdc-tab-indicator__content--underline {
  border-color: var(--%NS%mat-tab-active-indicator-color, var(--%NS%mat-sys-primary));
  border-top-width: var(--%NS%mat-tab-active-indicator-height, 2px);
  border-radius: var(--%NS%mat-tab-active-indicator-shape, 0);
}
.mat-mdc-tab-link:hover .mdc-tab__text-label {
  color: var(--%NS%mat-tab-inactive-hover-label-text-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link:focus .mdc-tab__text-label {
  color: var(--%NS%mat-tab-inactive-focus-label-text-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link.mdc-tab--active .mdc-tab__text-label {
  color: var(--%NS%mat-tab-active-label-text-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link.mdc-tab--active .mdc-tab__ripple::before,
.mat-mdc-tab-link.mdc-tab--active .mat-ripple-element {
  background-color: var(--%NS%mat-tab-active-ripple-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link.mdc-tab--%NS%active:hover .mdc-tab__text-label {
  color: var(--%NS%mat-tab-active-hover-label-text-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link.mdc-tab--%NS%active:hover .mdc-tab-indicator__content--underline {
  border-color: var(--%NS%mat-tab-active-hover-indicator-color, var(--%NS%mat-sys-primary));
}
.mat-mdc-tab-link.mdc-tab--%NS%active:focus .mdc-tab__text-label {
  color: var(--%NS%mat-tab-active-focus-label-text-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link.mdc-tab--%NS%active:focus .mdc-tab-indicator__content--underline {
  border-color: var(--%NS%mat-tab-active-focus-indicator-color, var(--%NS%mat-sys-primary));
}
.mat-mdc-tab-link.mat-mdc-tab-disabled {
  opacity: 0.4;
  pointer-events: none;
}
.mat-mdc-tab-link.mat-mdc-tab-disabled .mdc-tab__content {
  pointer-events: none;
}
.mat-mdc-tab-link.mat-mdc-tab-disabled .mdc-tab__ripple::before,
.mat-mdc-tab-link.mat-mdc-tab-disabled .mat-ripple-element {
  background-color: var(--%NS%mat-tab-disabled-ripple-color, var(--%NS%mat-sys-on-surface-variant));
}
.mat-mdc-tab-link .mdc-tab__ripple::before {
  content: "";
  display: block;
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  opacity: 0;
  pointer-events: none;
  background-color: var(--%NS%mat-tab-inactive-ripple-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-link .mdc-tab__text-label {
  color: var(--%NS%mat-tab-inactive-label-text-color, var(--%NS%mat-sys-on-surface));
  display: inline-flex;
  align-items: center;
}
.mat-mdc-tab-link .mdc-tab__content {
  position: relative;
  pointer-events: auto;
}
.mat-mdc-tab-link:hover .mdc-tab__ripple::before {
  opacity: 0.04;
}
.mat-mdc-tab-link.cdk-program-focused .mdc-tab__ripple::before, .mat-mdc-tab-link.cdk-keyboard-focused .mdc-tab__ripple::before {
  opacity: 0.12;
}
.mat-mdc-tab-link .mat-ripple-element {
  opacity: 0.12;
  background-color: var(--%NS%mat-tab-inactive-ripple-color, var(--%NS%mat-sys-on-surface));
}
.mat-mdc-tab-header.mat-mdc-tab-nav-bar-stretch-tabs .mat-mdc-tab-link {
  flex-grow: 1;
}
.mat-mdc-tab-link::before {
  margin: 5px;
}

@media (max-width: 599px) {
  .mat-mdc-tab-link {
    min-width: 72px;
  }
}
`],encapsulation:2})}return a})();var er=(()=>{class a{id=D(j).getId(`mat-tab-nav-panel-`);_activeTabId;static ɵfac=function(t){return new(t||a)};static ɵcmp=aS({type:a,selectors:[[`mat-tab-nav-panel`]],hostAttrs:[`role`,`tabpanel`,1,`mat-mdc-tab-nav-panel`],hostVars:2,hostBindings:function(t,n){t&2&&$p(`aria-labelledby`,n._activeTabId)(`id`,n.id)},inputs:{id:`id`},exportAs:[`matTabNavPanel`],ngContentSelectors:Fe,decls:1,vars:0,template:function(t,n){t&1&&(qS(),jS(0))},encapsulation:2})}return a})();export{on as n,sn as r,er as t};