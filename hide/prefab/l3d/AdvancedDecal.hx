package hide.prefab.l3d;

class AdvancedDecal extends Object3D {

	var albedoMap : String;
	var normalMap : String;
	var pbrMap : String;
	var albedoStrength : Float = 1.0;
	var normalStrength: Float = 1.0;
	var pbrStrength: Float = 1.0;
	var fadePower : Float = 1.0;
	var fadeStart : Float = 0;
	var fadeEnd : Float = 1.0;
	var emissive : Float = 0.0;
	var blendMode : h2d.BlendMode = Alpha;
	var renderMode : h3d.mat.PbrMaterial.PbrMode = Decal;
	var centered : Bool = true;

	override function save() {
		var obj : Dynamic = super.save();
		if(albedoMap != null) obj.albedoMap = albedoMap;
		if(normalMap != null) obj.normalMap = normalMap;
		if(pbrMap != null) obj.pbrMap = pbrMap;
		if(albedoStrength != 1) obj.albedoStrength = albedoStrength;
		if(normalStrength != 1) obj.normalStrength = normalStrength;
		if(pbrStrength != 1) obj.pbrStrength = pbrStrength;
		if(blendMode != Alpha) obj.blendMode = blendMode;
		if(centered != true) obj.centered = centered;
		if(fadePower != 1) obj.fadePower = fadePower;
		if(fadeStart != 0) obj.fadeStart = fadeStart;
		if(fadeEnd != 1) obj.fadeEnd = fadeEnd;
		if(renderMode != Decal) obj.renderMode = renderMode;
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		albedoMap = obj.albedoMap;
		normalMap = obj.normalMap;
		pbrMap = obj.pbrMap;
		albedoStrength = obj.albedoStrength != null ? obj.albedoStrength : 1;
		normalStrength = obj.normalStrength != null ? obj.normalStrength : 1;
		pbrStrength = obj.pbrStrength != null ? obj.pbrStrength : 1;
		blendMode = obj.blendMode != null ? obj.blendMode : Alpha;
		centered = obj.centered != null ? obj.centered : true;
		fadePower = obj.fadePower != null ? obj.fadePower : 1;
		fadeStart = obj.fadeStart != null ? obj.fadeStart : 0;
		fadeEnd = obj.fadeEnd != null ? obj.fadeEnd : 1;
		renderMode = obj.renderMode != null ? obj.renderMode : Decal;
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);
		var mesh = new h3d.scene.Mesh(h3d.prim.Cube.defaultUnitCube(), ctx.local3d);

		switch (renderMode) {
			case Decal:
				var shader = mesh.material.mainPass.getShader(h3d.shader.pbr.VolumeDecal.DecalPBR);
				if( shader == null ) {
					shader = new h3d.shader.pbr.VolumeDecal.DecalPBR();
					//shader.setPriority(-1);
					mesh.material.mainPass.addShader(shader);
				}
				mesh.material.mainPass.setPassName("decal");
			case BeforeTonemapping:
				var shader = mesh.material.mainPass.getShader(h3d.shader.pbr.VolumeDecal.DecalOverlay);
				if( shader == null ) {
					shader = new h3d.shader.pbr.VolumeDecal.DecalOverlay();
					mesh.material.mainPass.addShader(shader);
				}
				mesh.material.mainPass.setPassName("BeforeTonemapping");
			default:
		}

		mesh.material.mainPass.depthWrite = false;
		mesh.material.mainPass.depthTest = GreaterEqual;
		mesh.material.mainPass.culling = Front;
		ctx.local3d = mesh;
		ctx.local3d.name = name;
		updateInstance(ctx);
		return ctx;
	}

	override function updateInstance(ctx:Context,?propName:String) {
		super.updateInstance(ctx,propName);

		var mesh = Std.instance(ctx.local3d, h3d.scene.Mesh);
		mesh.material.blendMode = blendMode;

		switch (renderMode) {
			case Decal:
				var shader = mesh.material.mainPass.getShader(h3d.shader.pbr.VolumeDecal.DecalPBR);
				if( shader != null ){
					var b = mesh.getBounds();
					shader.minBound = new h3d.Vector(b.xMin, b.yMin, b.zMin);
					shader.maxBound = new h3d.Vector(b.xMax, b.yMax, b.zMax);
					shader.normal = mesh.getAbsPos().up();
					shader.tangent = mesh.getAbsPos().right();
					shader.albedoTexture = albedoMap != null ? ctx.loadTexture(albedoMap) : null;
					shader.normalTexture = normalMap != null ? ctx.loadTexture(normalMap) : null;
					shader.pbrTexture = pbrMap != null ? ctx.loadTexture(pbrMap) : null;
					if(shader.albedoTexture != null) shader.albedoTexture.wrap = Repeat;
					if(shader.normalTexture != null) shader.normalTexture.wrap = Repeat;
					if(shader.pbrTexture != null) shader.pbrTexture.wrap = Repeat;
					shader.albedoStrength = albedoStrength;
					shader.normalStrength = normalStrength;
					shader.pbrStrength = pbrStrength;
					shader.USE_ALBEDO = albedoStrength != 0;
					shader.USE_NORMAL = normalStrength != 0;
					shader.USE_PBR = pbrStrength != 0;
					shader.CENTERED = centered;
					shader.scale = new h3d.Vector(mesh.scaleX, mesh.scaleY, mesh.scaleZ);
					shader.fadePower = fadePower;
					shader.fadeStart = fadeStart;
					shader.fadeEnd = fadeEnd;
					shader.emissive = emissive;
				}
			case BeforeTonemapping:
				var shader = mesh.material.mainPass.getShader(h3d.shader.pbr.VolumeDecal.DecalOverlay);
				if( shader != null ){
					var b = mesh.getBounds();
					shader.minBound = new h3d.Vector(b.xMin, b.yMin, b.zMin);
					shader.maxBound = new h3d.Vector(b.xMax, b.yMax, b.zMax);
					shader.colorTexture = albedoMap != null ? ctx.loadTexture(albedoMap) : null;
					if(shader.colorTexture != null) shader.colorTexture.wrap = Repeat;
					shader.CENTERED = centered;
					shader.scale = new h3d.Vector(mesh.scaleX, mesh.scaleY, mesh.scaleZ);
					shader.fadePower = fadePower;
					shader.fadeStart = fadeStart;
					shader.fadeEnd = fadeEnd;
					shader.emissive = emissive;
				}
			default:
		}
	}

	#if editor
	override function getHideProps() : HideProps {
		return { icon : "paint-brush", name : "Decal" };
	}

	override function setSelected( ctx : Context, b : Bool ) {
		if( b ) {
			var obj = ctx.shared.contexts.get(this).local3d;
			var wire = new h3d.scene.Box(0xFFFFFFFF,obj);
			wire.name = "_highlight";
			wire.material.setDefaultProps("ui");
			wire.ignoreCollide = true;
			wire.material.shadows = false;
		} else {
			for( o in ctx.shared.getObjects(this,h3d.scene.Box) )
				if( o.name == "_highlight" ) {
					o.remove();
					return;
				}
		}
	}

	var pbrParams = '<dt>Albedo</dt><dd><input type="texturepath" field="albedoMap"/>
					<br/><input type="range" min="0" max="1" field="albedoStrength"/></dd>

					<dt>Normal</dt><dd><input type="texturepath" field="normalMap"/>
					<br/><input type="range" min="0" max="1" field="normalStrength"/></dd>

					<dt>PBR</dt><dd><input type="texturepath" field="pbrMap"/>
					<br/><input type="range" min="0" max="1" field="pbrStrength"/></dd>';

	var overlayParams = '<dt>Color</dt><dd><input type="texturepath" field="albedoMap"/>';

	override function edit( ctx : EditContext ) {
		super.edit(ctx);

		var params = switch (renderMode) {
			case Decal: pbrParams;
			case BeforeTonemapping: overlayParams;
			default: null;
		}

		var props = ctx.properties.add(new hide.Element('
			<div class="group" name="Decal">
				<dl>
					<dt>Centered</dt><dd><input type="checkbox" field="centered"/></dd>'
					+ params +
					'<dt>Render Mode</dt>
					<dd><select field="renderMode">
						<option value="Decal">PBR</option>
						<option value="BeforeTonemapping">Overlay</option>
					</select></dd>

					<dt>Blend Mode</dt>
					<dd><select field="blendMode">
						<option value="Alpha">Alpha</option>
						<option value="Add">Add</option>
					</select></dd>
					<dt>Emissive</dt><dd> <input type="range" min="0" max="10" field="emissive"/></dd>
				</dl>
			</div>
			<div class="group" name="Fade">
				<dt>FadePower</dt><dd> <input type="range" min="0" max="10" field="fadePower"/></dd>
				<dt>Start</dt><dd> <input type="range" min="0" max="1" field="fadeStart"/></dd>
				<dt>End</dt><dd> <input type="range" min="0" max="1" field="fadeEnd"/></dd>
			</div>
		'),this, function(pname) {
			ctx.onChange(this, pname);
		});
	}
	#end

	static var _ = hxd.prefab.Library.register("advancedDecal", AdvancedDecal);

}