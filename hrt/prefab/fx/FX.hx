package hrt.prefab.fx;
import hrt.prefab.fx.BaseFX.AdditionalProperies;
import hrt.prefab.Curve;
import hrt.prefab.Prefab as PrefabElement;
import hrt.prefab.fx.BaseFX.ObjectAnimation;
import hrt.prefab.fx.BaseFX.ShaderAnimation;


@:allow(hrt.prefab.fx.FX)
class FXAnimation extends h3d.scene.Object {

	public var onEnd : Void -> Void;
	public var playSpeed : Float = 0;
	public var localTime : Float = 0.0;
	var totalTime : Float = 0.0;
	public var duration : Float;
	public var additionLoopDuration : Float = 0.0;
	public var cullingRadius : Float;

	public var objAnims: Array<ObjectAnimation>;
	public var events: Array<hrt.prefab.fx.Event.EventInstance>;
	public var emitters : Array<hrt.prefab.fx.Emitter.EmitterObject>;
	public var shaderAnims : Array<ShaderAnimation> = [];
	public var constraints : Array<hrt.prefab.l3d.Constraint>;
	public var script : hrt.prefab.fx.FXScript;

	public var vecPool = new Evaluator.VecPool();
	var evaluator : Evaluator;
	var random : hxd.Rand;
	var prevTime = -1.0;
	var randSeed : Int;

	var startLoop : Float = -1.0;
	var endLoop : Float;

	public function new(?parent) {
		super(parent);
		randSeed = Std.random(0xFFFFFF);
		random = new hxd.Rand(randSeed);
		evaluator = new Evaluator(random);
		evaluator.vecPool = vecPool;
		name = "FXAnimation";
		inheritCulled = true;
	}

	function init(ctx: Context, def: FX, ?root: PrefabElement) {
		if(root == null)
			root = def;
		initObjAnimations(ctx, root);
		initEmitters(ctx, root);
		BaseFX.getShaderAnims(ctx, root, shaderAnims);
		events = initEvents(root, ctx);
		if (events != null) {
			for (e in events) {
				if (e.evt.name == "startLoop") {
					startLoop = e.evt.time;
				} else if (e.evt.name == "endLoop") {
					endLoop = e.evt.time;
				}
			}
		}
		var root = def.getFXRoot(ctx, def);
		initConstraints(ctx, root != null ? root : def);
		for(s in shaderAnims)
			s.vecPool = vecPool;
	}

	override function onRemove() {
		super.onRemove();
		if(objAnims != null)
			for(obj in objAnims)
				obj.obj.remove();
		if(emitters != null)
			for(emitter in emitters)
				emitter.reset();
	}

	public function setRandSeed(seed: Int) {
		randSeed = seed;
		random.init(seed);
		if(emitters != null)
			for(em in emitters)
				em.setRandSeed(randSeed);
	}

	override function sync( ctx : h3d.scene.RenderContext ) {
		if(emitters != null)
			for(emitter in emitters)
				emitter.setParticleVibility(ctx.visibleFlag);

		if (additionLoopDuration > 0 && startLoop >= 0) {
			if (totalTime > startLoop) {
				var timeLeft = endLoop + additionLoopDuration - totalTime;
				if (timeLeft > 0) {
					this.localTime = startLoop + ((totalTime - startLoop) % (endLoop - startLoop));
				} else {
					this.localTime = endLoop - timeLeft;
				}
			}
		}

		if(playSpeed > 0) {
			var curTime = localTime;
			if( ctx.visibleFlag || alwaysSync ) setTime(curTime);
			localTime += ctx.elapsedTime * playSpeed;
			totalTime += ctx.elapsedTime;
			if( duration > 0 && curTime < duration && localTime >= duration) {
				localTime = duration;
				if( onEnd != null )
					onEnd();
			}
		}
	}

	static var tempMat = new h3d.Matrix();
	static var tempTransform = new h3d.Matrix();
	static var tempVec = new h3d.Vector();
	public function setTime( time : Float ) {
		this.localTime = time;
		vecPool.begin();
		if(objAnims != null) {
			for(anim in objAnims) {
				if(anim.scale != null || anim.rotation != null || anim.position != null) {
					var m = tempMat;
					if(anim.scale != null) {
						var scale = evaluator.getVector(anim.scale, time, tempVec);
						m.initScale(scale.x, scale.y, scale.z);
					}
					else
						m.identity();

					if(anim.rotation != null) {
						var rotation = evaluator.getVector(anim.rotation, time, tempVec);
						rotation.scale3(Math.PI / 180.0);
						m.rotate(rotation.x, rotation.y, rotation.z);
					}

					var baseMat = anim.elt.getTransform(tempTransform);
					var offset = baseMat.getPosition(tempVec);
					baseMat.tx = baseMat.ty = baseMat.tz = 0.0;  // Ignore
					m.multiply(baseMat, m);
					m.translate(offset.x, offset.y, offset.z);

					if(anim.position != null) {
						var pos = evaluator.getVector(anim.position, time, tempVec);
						m.translate(pos.x, pos.y, pos.z);
					}

					anim.obj.setTransform(m);
				}

				if(anim.visibility != null)
					anim.obj.visible = anim.elt.visible && evaluator.getFloat(anim.visibility, time) > 0.5;

				if(anim.color != null) {
					switch(anim.color) {
						case VCurve(a):
							for(mat in anim.obj.getMaterials())
								mat.color.a = evaluator.getFloat(anim.color, time);
						default:
							for(mat in anim.obj.getMaterials())
								mat.color.load(evaluator.getVector(anim.color, time, tempVec));
					}
				}
				Event.updateEvents(anim.events, time, prevTime);

				if( anim.additionalProperies != null ) {
					switch(anim.additionalProperies) {
						case None :
						case PointLight( color, power, size, range ) :
							var l = Std.downcast(anim.obj, h3d.scene.pbr.PointLight);
							if( l != null ) {
								if( color != null ) l.color = evaluator.getVector(color, time, tempVec);
								if( power != null ) l.power = evaluator.getFloat(power, time);
								if( size != null ) l.size = evaluator.getFloat(size, time);
								if( range != null ) l.range = evaluator.getFloat(range, time);
							}
						case DirLight(color, power):
							var l = Std.downcast(anim.obj, h3d.scene.pbr.DirLight);
							if( l != null ) {
								if( color != null ) l.color = evaluator.getVector(color, time, tempVec);
								if( power != null ) l.power = evaluator.getFloat(power, time);
							}
						case SpotLight(color, power, range, angle, fallOff):
							var l = Std.downcast(anim.obj, h3d.scene.pbr.SpotLight);
							if( l != null ) {
								if( color != null ) l.color = evaluator.getVector(color, time, tempVec);
								if( power != null ) l.power = evaluator.getFloat(power, time);
								if( range != null ) l.range = evaluator.getFloat(range, time);
								if( angle != null ) l.angle = evaluator.getFloat(angle, time);
								if( fallOff != null ) l.fallOff = evaluator.getFloat(fallOff, time);
							}
					}
				}
			}
		}

		if(shaderAnims != null)
			for(anim in shaderAnims)
				anim.setTime(time);

		if(emitters != null) {
			for(em in emitters) {
				if (prevTime > localTime) {
					@:privateAccess em.curTime = em.lastTime = time;
					#if editor
					em.reset();
					#end
				}
				if(em.visible)
					em.setTime(time);
			}
		}

		Event.updateEvents(events, time, prevTime);

		if(script != null)
			script.update();

		this.prevTime = localTime;
	}

	function initEvents(elt: PrefabElement, ctx: Context) {
		var childEvents = [for(c in elt.children) if(c.to(Event) != null) c.to(Event)];
		var ret = null;
		for(evt in childEvents) {
			var eventObj = evt.prepare(ctx);
			if(eventObj == null) continue;
			if(ret == null) ret = [];
			ret.push(eventObj);
		}
		return ret;
	}

	function initObjAnimations(ctx:Context, elt: PrefabElement) {
		if(Std.downcast(elt, hrt.prefab.fx.Emitter) == null) {
			// Don't extract animations for children of Emitters
			for(c in elt.children) {
				initObjAnimations(ctx, c);
			}
		}

		var obj3d = elt.to(hrt.prefab.Object3D);
		if(obj3d == null)
			return;

		// TODO: Support references?
		var objCtx = ctx.shared.contexts.get(elt);
		if(objCtx == null || objCtx.local3d == null)
			return;

		var anyFound = false;

		function makeVal(name, def) : Value {
			var c = Curve.getCurve(elt, name);
			if(c != null)
				anyFound = true;
			return c != null ? VCurve(c) : def;
		}

		function makeVector(name: String, defVal: Float, uniform: Bool=true, scale: Float=1.0) : Value {
			var curves = Curve.getCurves(elt, name);
			if(curves == null || curves.length == 0)
				return null;

			anyFound = true;

			if(uniform && curves.length == 1 && curves[0].name == name)
				return scale != 1.0 ? VCurveScale(curves[0], scale) : VCurve(curves[0]);

			return Curve.getVectorValue(curves, defVal, scale);
		}

		function makeColor(name: String) {
			var curves = Curve.getCurves(elt, name);
			if(curves == null || curves.length == 0)
				return null;

			anyFound = true;
			return Curve.getColorValue(curves);
		}

		var ap : AdditionalProperies = null;
		if( Std.is(objCtx.local3d, h3d.scene.pbr.PointLight)) {
			ap = PointLight(makeColor("color"), makeVal("power", null), makeVal("size", null), makeVal("range", null) );
		}
		else if( Std.is(objCtx.local3d, h3d.scene.pbr.SpotLight)) {
			ap = SpotLight(makeColor("color"), makeVal("power", null), makeVal("range", null), makeVal("angle", null), makeVal("fallOff", null) );
		}
		else if( Std.is(objCtx.local3d, h3d.scene.pbr.DirLight)) {
			ap = DirLight(makeColor("color"), makeVal("power", null));
		}

		var anim : ObjectAnimation = {
			elt: obj3d,
			obj: objCtx.local3d,
			events: null,
			position: makeVector("position", 0.0),
			scale: makeVector("scale", 1.0, true),
			rotation: makeVector("rotation", 0.0, 360.0),
			color: makeColor("color"),
			visibility: makeVal("visibility", null),
			additionalProperies: ap,
		};

		anim.events = initEvents(elt, objCtx);
		if(anim.events != null)
			anyFound = true;

		if(anyFound) {
			if(objAnims == null) objAnims = [];
			objAnims.push(anim);
		}
	}

	function initEmitters(ctx: Context, elt: PrefabElement) {
		var em = Std.downcast(elt, hrt.prefab.fx.Emitter);
		if(em != null)  {
			for(emCtx in ctx.shared.getContexts(elt)) {
				if(emCtx.local3d == null) continue;
				if(emitters == null) emitters = [];
				var emobj : hrt.prefab.fx.Emitter.EmitterObject = cast emCtx.local3d;
				emobj.setRandSeed(randSeed);
				emitters.push(emobj);
			}
		}
		else {
			for(c in elt.children) {
				initEmitters(ctx, c);
			}
		}
	}

	function initConstraints( ctx : Context, elt : PrefabElement ){
		var co = Std.downcast(elt, hrt.prefab.l3d.Constraint);
		if(co != null) {
			if(constraints == null) constraints = [];
			constraints.push(co);
		}
		else
			for(c in elt.children)
				initConstraints(ctx, c);
	}

	public function resolveConstraints( caster : h3d.scene.Object ) {
		for( co in constraints ) {
			if( !co.enabled )
		 		continue;

			var objectName = co.object.split(".").pop();
			var targetName = co.target.split(".").pop();

			var isInFX = co.object.split(".")[1] == "FXRoot";
			var srcObj = objectName == "FXRoot" ? this : isInFX ? this.getObjectByName(objectName) : caster.getObjectByName(objectName);
			var targetObj = caster.getObjectByName(targetName);
			if( srcObj != null && targetObj != null ) {
				srcObj.follow = targetObj;
				srcObj.followPositionOnly = co.positionOnly;
			}
		}
	}
}

class FX extends BaseFX {
	@:s public var vars : Array<{ name : String, defValue : Float }> = [];
	public var values : Map<String, Float> = new Map();

	var prefabCache : Map<String, { r : Prefab }> = new Map();
	var particlesCache : Map<String, { v : h3d.scene.Object }> = new Map();

	// #if hscript
	// public var interp : hrt.prefab.rfx.Configurator.ConfiguratorInterp;
	// public var parsedExpr : hscript.Expr;
	// #end
	#if editor
	public var errorTarget : hide.Element;
	#end
	var rootPrefab : Prefab;

	public var scriptEditor : hide.comp.ScriptEditor;
	public var scriptParser : hrt.prefab.fx.FXScriptParser;


	public function new() {
		super();
		type = "fx";
		cullingRadius = 3.0;
	}

	override function save() {
		var obj : Dynamic = super.save();
		obj.cullingRadius = cullingRadius;
		if( scriptCode != "" ) obj.scriptCode = scriptCode;
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		if(obj.cullingRadius != null)
			cullingRadius = obj.cullingRadius;
		scriptCode = obj.scriptCode;
	}

	function resetCache() {
		prefabCache = [];
		particlesCache = [];
	}

	override function makeInstance(ctx:Context):Context {
		for( v in vars )
			values.set(v.name, v.defValue);
		rootPrefab = this;
		var shared = ctx.shared;
		while( shared.parent != null ) {
			rootPrefab = shared.parent.prefab;
			shared = shared.parent.shared;
		}
		while( rootPrefab.parent != null )
			rootPrefab = rootPrefab.parent;
		resetCache();
		// #if hscript
		// interp = null;
		// #end
		return super.makeInstance(ctx);
	}

	override function make( ctx : Context ) : Context {
		ctx = ctx.clone(this);
		var fxanim = createInstance(ctx.local3d);
		fxanim.duration = duration;
		fxanim.cullingRadius = cullingRadius;
		ctx.local3d = fxanim;
		var fromRef = ctx.shared.parent != null;
		#if editor
		// only play if we are as a reference
		if( fromRef ) fxanim.playSpeed = 1.0;
		#else
		fxanim.playSpeed = 1.0;
		#end

		var useFXRoot = #if editor fromRef #else true #end;
		var root = getFXRoot(ctx, this);
		if(useFXRoot && root != null){
			for( c in root.children ) {
				var co = Std.downcast(c , hrt.prefab.l3d.Constraint);
				if( co == null )
					makeChildren(ctx,c);
			}
		}
		else
			super.make(ctx);
		fxanim.init(ctx, this, root);

		if(scriptCode != null && scriptCode != ""){
			var parser = new FXScriptParser();
			fxanim.script = parser.createFXScript(scriptCode, fxanim);
			fxanim.script.init();
		}

		return ctx;
	}

	override function updateInstance( ctx: Context, ?propName : String ) {
		super.updateInstance(ctx, null);
		var fxanim = Std.downcast(ctx.local3d, FXAnimation);
		fxanim.duration = duration;
		fxanim.cullingRadius = cullingRadius;
		// #if !hscript
		// throw "Requires -lib hscript";
		// #else
		// var errorMessage = null;
		// if( parsedExpr == null && scriptCode != null) {
		// 	var parser = new hscript.Parser();
		// 	parsedExpr = try parser.parseString(scriptCode) catch( e : hscript.Expr.Error ) { errorMessage = hscript.Printer.errorToString(e); null; };
		// }
		// if( interp == null ) {
		// 	interp = new hrt.prefab.rfx.Configurator.ConfiguratorInterp();
		// 	interp.variables.set("get", getPrefab.bind(false));
		// 	// interp.variables.set("getParts", getParts.bind(r));
		// 	// interp.variables.set("getOpt", getPrefab.bind(true));
		// 	interp.variables.set("smooth", smoothValue);
		// 	interp.variables.set("allowChanges", allowChanges);
		// }
		for( k => v in values )
			scriptParser.contextVars.set(k, v);
		// if( errorMessage == null )
		// 	try {
		// 		interp.execute(parsedExpr);
		// 	} catch( e : Dynamic ) {
		// 		errorMessage = Std.string(e);
		// 	}
		// if( scriptParser.errorMessage != null ) {
		// 	#if !editor
		// 	throw scriptParser.errorMessage;
		// 	#else
		// 	if( errorTarget != null ) errorTarget.text(scriptParser.errorMessage);
		// 	#end
		// } else {
		// 	#if editor
		// 	if( errorTarget != null ) errorTarget.html("&nbsp;");
		// 	#end
		// }
		// #end
		// interp.restoreVars();
	}

	function createInstance(parent: h3d.scene.Object) : FXAnimation {
		return new FXAnimation(parent);
	}

	#if editor

	override function refreshObjectAnims(ctx: Context) {
		var fxanim = Std.downcast(ctx.local3d, FXAnimation);
		fxanim.objAnims = null;
		fxanim.initObjAnimations(ctx, this);
	}

	public function smoothValue( v : Float, easing : Float ) : Float {
		var bpow = Math.pow(v, 1 + easing);
		return bpow / (bpow + Math.pow(1 - v, easing + 1));
	}

	// function getParts( r : Renderer, id : String) {
	// 	var p = particlesCache.get(id);
	// 	if (p != null)
	// 		return p.v;
	// 	var obj = r.ctx.scene.getObjectByName(id);
	// 	if ( obj == null)
	// 		throw "Missing object #"+id;
	// 	#if !editor
	// 	particlesCache.set(id, { v : obj });
	// 	#end
	// 	return obj;
	// }

	public function getPrefab( opt : Bool, id : String ) {
		var p = prefabCache.get(id);
		if( p != null )
			return p.r;
		var p = rootPrefab.getOpt(hrt.prefab.Prefab,id,true);
		if( p == null ) {
			if( opt ) return null;
			throw "Missing prefab #"+id;
		}
		#if !editor
		prefabCache.set(id, { r : p });
		#end
		return p;
	}

	// #if hscript
	// public function allowChanges( v : Bool ) {
	// 	interp.allowChanges = v;
	// }
	// #end

	override function edit( ectx : EditContext ) {
		var props = new hide.Element('
			<div class="group" name="FX Scene">
				<dl>
					<dt>Duration</dt><dd><input type="number" value="0" field="duration"/></dd>
					<dt>Culling radius</dt><dd><input type="number" field="cullingRadius"/></dd>
				</dl>
			</div>
			<div>
				<div class="group" name="Variables">
					<dl id="vars">
					</dl>
					<dl>
						<dt></dt>
						<dd><input type="button" value="Add" id="addvar"/></dd>
					</dl>
				</div>
				<div class="group" name="Script">
				<div>
					<div class="error">&nbsp;</div>
					<div id="script" style="height:200px"></div>
				</div>
				</div>
			</div>
		');

		errorTarget = props.find(".error");
		var evars = props.find("#vars");
		props.find("#addvar").click(function(_) {
			var name = ectx.ide.ask("Variable name");
			if( name == null ) return;
			ectx.makeChanges(this, function() vars.push({ name : name, defValue: 0 }));
			values.set(name, 0);
			ectx.rebuildProperties();
		});
		ectx.properties.add(props, this, function(pname) {
			ectx.onChange(this, pname);
		});
		for( v in vars ) {
			var ref = { v : values.get(v.name) };
			var def = new hide.Element('<div class="variable"><dt>${v.name}</dt><dd><input type="range" min="0" max="1" field="v"/></dd></div>').appendTo(evars);
			ectx.properties.build(def, ref, function(pname) {
				values.set(v.name, ref.v);
				ectx.onChange(this, pname);
			});
			def.find("dt").contextmenu(function(e) {
				new hide.comp.ContextMenu([
					{ label : "Set Default", click : () -> v.defValue = ref.v },
					{ label : "Remove", click : () -> {
						vars.remove(v);
						values.remove(v.name);
						//interp.variables.remove(v.name);
						ectx.rebuildProperties();
					}},
				]);
				return false;
			});
		}

		var scriptElem = props.find("#script");
		scriptEditor = new hide.comp.ScriptEditor(scriptCode, null, scriptElem, scriptElem);
		if (scriptParser == null)
			scriptParser = new hrt.prefab.fx.FXScriptParser();
		scriptCode = scriptEditor.code;
	}

	override function getHideProps() : HideProps {
		return { icon : "cube", name : "FX", allowParent: _ -> false};
	}
	#end

	static var _ = Library.register("fx", FX, "fx");
}