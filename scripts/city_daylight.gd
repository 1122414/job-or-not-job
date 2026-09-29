class_name CityDaylight
extends RefCounted

# Local art direction for a clear coastal day. Dawn and twilight have their
# own keys; direct sunlight ends at the horizon while the sky fades later.
# minute, sun energy, ambient energy, sky contribution, zenith, horizon,
# sunlight colour, ambient colour
const KEYS := [
	[0,0.0,.24,.15,Color("081526"),Color("203448"),Color("ffd5b1"),Color("99afc9")],
	[300,0.0,.24,.15,Color("081526"),Color("203448"),Color("ffd5b1"),Color("99afc9")],
	[360,0.0,.32,.25,Color("354d70"),Color("b68178"),Color("ffc092"),Color("bac4d3")],
	[420,.48,.46,.4,Color("5f87ad"),Color("d9c0ac"),Color("ffdab3"),Color("d3d6d9")],
	[540,.92,.53,.5,Color("4f83ad"),Color("bfd3df"),Color("fff1da"),Color("d7e0e5")],
	[720,1.12,.56,.55,Color("467eae"),Color("c6dbe4"),Color("fff7e9"),Color("d7e2ec")],
	[900,.94,.52,.5,Color("4f83ad"),Color("cad5d9"),Color("ffecd2"),Color("d7dee4")],
	[1020,.54,.43,.4,Color("667f9e"),Color("ddbc9b"),Color("ffd09e"),Color("d5d1cf")],
	[1080,0.0,.33,.3,Color("405c82"),Color("b8796d"),Color("ffbd8e"),Color("b6bfd2")],
	[1110,0.0,.28,.22,Color("253d61"),Color("6d657b"),Color("ffd5b1"),Color("a3b4ce")],
	[1170,0.0,.24,.15,Color("081526"),Color("203448"),Color("ffd5b1"),Color("99afc9")],
	[1440,0.0,.24,.15,Color("081526"),Color("203448"),Color("ffd5b1"),Color("99afc9")]
]

static func apply(sun: DirectionalLight3D,environment: Environment,minute: float) -> float:
	var local := fposmod(minute,1440.0)
	var index := 0
	while index<KEYS.size()-2 and local>KEYS[index+1][0]: index+=1
	var a: Array=KEYS[index]
	var b: Array=KEYS[index+1]
	var weight := smoothstep(a[0],b[0],local)
	sun.light_energy=lerpf(a[1],b[1],weight)
	sun.light_color=a[6].lerp(b[6],weight)
	sun.rotation_degrees=Vector3(-(local/60.0-6.0)*15.0,-25,0)
	sun.shadow_enabled=sun.light_energy>0.0
	environment.ambient_light_energy=lerpf(a[2],b[2],weight)
	environment.ambient_light_sky_contribution=lerpf(a[3],b[3],weight)
	environment.ambient_light_color=a[7].lerp(b[7],weight)
	var sky: ProceduralSkyMaterial=environment.sky.sky_material
	sky.sky_top_color=a[4].lerp(b[4],weight)
	sky.sky_horizon_color=a[5].lerp(b[5],weight)
	sky.ground_horizon_color=sky.sky_horizon_color
	var daylight := clampf(sun.light_energy/1.12,0,1)
	sky.ground_bottom_color=Color("17202b").lerp(Color("748174"),daylight)
	environment.background_color=sky.sky_horizon_color
	environment.fog_light_color=sky.sky_horizon_color
	return daylight
