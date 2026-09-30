"""Convert selected CC0 MakeHuman meshes/weights to skinned, textured glTF.
Usage: python3 tools/build_characters.py SOURCE_DIRECTORY
See docs/assets.md for original authors, downloads and reproducibility.
No Blender or third-party Python modules required.
"""
from pathlib import Path
from collections import defaultdict
import json, math, struct, sys

SOURCE = None
OUTPUT = Path('assets/characters')

def obj(path):
    vertices=[]; uvs=[]; faces=[]; group=''
    for line in path.read_text().splitlines():
        p=line.split()
        if not p: continue
        if p[0]=='v': vertices.append(tuple(map(float,p[1:4])))
        elif p[0]=='vt': uvs.append((float(p[1]),1-float(p[2])))
        elif p[0]=='g': group=p[1]
        elif p[0]=='f':
            f=[]
            for item in p[1:]:
                ids=item.split('/');f.append((int(ids[0])-1,int(ids[1])-1 if len(ids)>1 and ids[1] else 0))
            for i in range(1,len(f)-1): faces.append((group,[f[0],f[i],f[i+1]]))
    return vertices,uvs,faces

def configure(source, targets=None, output_scale=0.106):
    global SOURCE, base, base_uv, base_faces, rig, names, index, weights, scale, floor, heads
    SOURCE = Path(source)
    base, base_uv, base_faces = obj(SOURCE/'base.obj')
    for target, amount in (targets or {}).items():
        for vertex, delta in read_target(target).items():
            base[vertex] = tuple(base[vertex][axis] + amount*delta[axis] for axis in range(3))
    rig = json.loads((SOURCE/'default.mhskel').read_text())
    names = list(rig['bones'])
    index = {name: i for i, name in enumerate(names)}
    weights = defaultdict(dict)
    for bone, entries in json.loads((SOURCE/'default_weights.mhw').read_text())['weights'].items():
        for vertex, weight in entries:
            weights[vertex][index[bone]] = weight
    scale = output_scale
    floor = min(base[vi][1] for group, face in base_faces if group == 'body' for vi, uv in face)
    heads = {}
    for name, bone in rig['bones'].items():
        ids = rig['joints'][bone['head']]
        heads[name] = convert([sum(base[i][axis] for i in ids)/len(ids) for axis in range(3)])


def read_target(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if not fields or fields[0].startswith('#'):
            continue
        if len(fields) != 4:
            raise ValueError(f'Invalid morph line in {path}')
        result[int(fields[0])] = tuple(map(float, fields[1:]))
    return result


def convert(vertex):
    return (vertex[0]*scale, (vertex[1]-floor)*scale, vertex[2]*scale)

def clothing(path, positive_skin=False):
    lines=path.read_text().splitlines(); mode=''; mapping=[]; hidden=set(); meta={}
    for line in lines:
        p=line.split()
        if not p or p[0].startswith('#'): continue
        if p[0] in ['verts','delete_verts']: mode=p[0];continue
        if not p[0].lstrip('-').isdigit():
            meta[p[0]]=' '.join(p[1:]);continue
        if mode=='verts':
            if len(p)==1: mapping.append(([int(p[0])],[1.0],[0,0,0]))
            else: mapping.append((list(map(int,p[:3])),list(map(float,p[3:6])),list(map(float,p[6:9]))))
        if mode=='delete_verts':
            i=0
            while i<len(p):
                if i+2<len(p) and p[i+1]=='-': hidden.update(range(int(p[i]),int(p[i+2])+1));i+=3
                else: hidden.add(int(p[i]));i+=1
    vertices,uvs,faces=obj(path.parent/meta['obj_file'])
    fitted=[]; skin=[]
    scales=[]
    for axis,key in enumerate(['x_scale','y_scale','z_scale']):
        raw=meta.get(key,'').split()
        scales.append(abs(base[int(raw[0])][axis]-base[int(raw[1])][axis])/float(raw[2]) if raw else 1)
    for vi,(ids,ws,offset) in enumerate(mapping):
        fitted.append(tuple(sum(base[i][a]*w for i,w in zip(ids,ws))+offset[a]*scales[a] for a in range(3)))
        blend=defaultdict(float)
        for i,w in zip(ids,ws):
            for b,bw in weights[i].items():
                contribution=w*bw
                if not positive_skin or contribution>0: blend[b]+=contribution
        skin.append(blend)
    assert len(fitted)==len(vertices),(path,len(fitted),len(vertices))
    mat={}
    mat_path=path.parent/meta.get('material','')
    if mat_path.is_file():
        for line in mat_path.read_text().splitlines():
            p=line.split(maxsplit=1)
            if len(p)==2: mat[p[0]]=p[1]
    return fitted,uvs,faces,skin,hidden,mat,mat_path.parent

class GLTF:
    def __init__(self):
        self.blob=bytearray()
        self.doc={'asset':{'version':'2.0','generator':'TodayOff CC0 character converter'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],'accessors':[],'bufferViews':[],'buffers':[],'images':[],'textures':[],'skins':[]}
        self.texture_cache={}
        for name in names:
            parent=rig['bones'][name]['parent'];pos=heads[name]
            local=[pos[a]-(heads[parent][a] if parent else 0) for a in range(3)]
            self.doc['nodes'].append({'name':name,'translation':local,'children':[]})
        roots=[]
        for name in names:
            parent=rig['bones'][name]['parent']
            if parent:self.doc['nodes'][index[parent]]['children'].append(index[name])
            else:roots.append(index[name])
        self.doc['scenes'][0]['nodes']=roots
        inverse=[]
        for name in names:
            x,y,z=heads[name];inverse.append([1,0,0,0,0,1,0,0,0,0,1,0,-x,-y,-z,1])
        accessor=self.accessor(inverse,'f','MAT4',5126)
        self.doc['skins'].append({'joints':list(range(len(names))),'inverseBindMatrices':accessor,'skeleton':roots[0]})
    def view(self,data):
        while len(self.blob)%4:self.blob.append(0)
        start=len(self.blob);self.blob.extend(data)
        self.doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(data)})
        return len(self.doc['bufferViews'])-1
    def accessor(self,values,fmt,kind,component):
        flat=[n for v in values for n in (v if isinstance(v,(list,tuple)) else [v])]
        view=self.view(struct.pack('<'+fmt*len(flat),*flat))
        item={'bufferView':view,'componentType':component,'count':len(values),'type':kind}
        if kind=='VEC3':
            item['min']=[min(v[a] for v in values) for a in range(3)]
            item['max']=[max(v[a] for v in values) for a in range(3)]
        self.doc['accessors'].append(item);return len(self.doc['accessors'])-1
    def texture(self, path):
        key = str(path)
        if key not in self.texture_cache:
            image = len(self.doc['images'])
            self.doc['images'].append({'bufferView': self.view(path.read_bytes()), 'mimeType': 'image/png' if path.suffix.lower() == '.png' else 'image/jpeg'})
            self.texture_cache[key] = len(self.doc['textures'])
            self.doc['textures'].append({'source': image})
        return self.texture_cache[key]

    def material(self,name,texture=None,color=(1,1,1,1),alpha=False,roughness=0.87,normal=None,occlusion=None,double_sided=True):
        pbr={'baseColorFactor':list(color),'metallicFactor':0,'roughnessFactor':roughness}
        if texture and texture.is_file():
            pbr['baseColorTexture']={'index':self.texture(texture)}
        item={'name':name,'pbrMetallicRoughness':pbr,'doubleSided':double_sided}
        if normal:
            item['normalTexture']={'index':self.texture(normal)}
        if occlusion:
            item['occlusionTexture']={'index':self.texture(occlusion)}
        if alpha:item.update(alphaMode='MASK',alphaCutoff=0.4)
        self.doc['materials'].append(item);return len(self.doc['materials'])-1
    def mesh(self,name,vertices,uvs,faces,skin,material,hidden=None,morphs=None):
        faces=[f for group,f in faces if hidden is None or not any(i in hidden for i,u in f)]
        normals=[[0,0,0] for _ in vertices]
        for face in faces:
            a,b,c=[vertices[i] for i,u in face]
            x=[b[i]-a[i] for i in range(3)];y=[c[i]-a[i] for i in range(3)]
            n=[x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0]]
            for i,u in face:
                for j in range(3):normals[i][j]+=n[j]
        positions=[];coords=[];normal=[];joints=[];strength=[];triangles=[];unique={}
        for face in faces:
            for i,u in face:
                key=(i,u)
                if key not in unique:
                    unique[key]=len(positions);positions.append(convert(vertices[i]));coords.append(uvs[u] if uvs else (0,0))
                    n=normals[i];length=math.sqrt(sum(x*x for x in n)) or 1
                    normal.append([x/length for x in n])
                    w=sorted(skin[i].items(),key=lambda p:-p[1])[:4] or [(index['root'],1)]
                    total=sum(v for b,v in w);w += [(0,0)]*(4-len(w))
                    joints.append([b for b,v in w]);strength.append([v/total for b,v in w])
                triangles.append(unique[key])
        attributes={}
        for key,data,fmt,kind,component in [('POSITION',positions,'f','VEC3',5126),('NORMAL',normal,'f','VEC3',5126),('TEXCOORD_0',coords,'f','VEC2',5126),('JOINTS_0',joints,'H','VEC4',5123),('WEIGHTS_0',strength,'f','VEC4',5126)]:attributes[key]=self.accessor(data,fmt,kind,component)
        indices=self.accessor(triangles,'I','SCALAR',5125)
        mesh=len(self.doc['meshes'])
        primitive={'attributes':attributes,'indices':indices,'material':material}
        definition={'name':name,'primitives':[primitive]}
        if morphs:
            primitive['targets']=[]
            definition['extras']={'targetNames':list(morphs)}
            definition['weights']=[0.0]*len(morphs)
            for deltas in morphs.values():
                values=[tuple(deltas.get(vertex,(0,0,0))[a]*scale for a in range(3)) for vertex,uv in unique]
                deformed=[tuple(v[a]+deltas.get(i,(0,0,0))[a] for a in range(3)) for i,v in enumerate(vertices)]
                target_normals=vertex_normals(deformed,faces)
                normal_deltas=[tuple(target_normals[vertex][a]-normal[exported][a] for a in range(3)) for exported,(vertex,uv) in enumerate(unique)]
                primitive['targets'].append({'POSITION':self.accessor(values,'f','VEC3',5126),'NORMAL':self.accessor(normal_deltas,'f','VEC3',5126)})
        self.doc['meshes'].append(definition)
        node=len(self.doc['nodes']);self.doc['nodes'].append({'name':name,'mesh':mesh,'skin':0});self.doc['scenes'][0]['nodes'].append(node)
    def save(self,path):
        self.doc['buffers']=[{'byteLength':len(self.blob)}]
        text=json.dumps(self.doc,separators=(',',':')).encode()
        text+=b' '*((-len(text))%4);self.blob+=b'\x00'*((-len(self.blob))%4)
        length=12+8+len(text)+8+len(self.blob)
        path.write_bytes(struct.pack('<III',0x46546C67,2,length)+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(self.blob),0x004e4942)+self.blob)

def vertex_normals(vertices, faces):
    normals=[[0.0,0.0,0.0] for _ in vertices]
    for face in faces:
        a,b,c=[vertices[i] for i,u in face]
        x=[b[i]-a[i] for i in range(3)]; y=[c[i]-a[i] for i in range(3)]
        n=(x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0])
        for vertex,uv in face:
            for axis in range(3): normals[vertex][axis]+=n[axis]
    return [tuple(x/(math.sqrt(sum(y*y for y in n)) or 1.0) for x in n) for n in normals]

# Selection of outfits and textures is deliberately explicit, never copied wholesale.
def find(name):
    matches=list(SOURCE.rglob(name))
    if len(matches)!=1:raise RuntimeError((name,matches))
    return matches[0]

def build(outfit,output,female=False):
    model=GLTF();parts=[];hidden=set()
    for name in [outfit,'shoes01','bob01' if female else 'short02']:
        file=find(name+'.mhclo')
        item=clothing(file,positive_skin=True);parts.append((name,item));hidden.update(item[4])
    skin_file=find('young_lightskinned_female_diffuse3.png' if female else 'young_lightskinned_male_diffuse3.png')
    mat=model.material('skin',skin_file)
    body=[(g,f) for g,f in base_faces if g=='body']
    model.mesh('body',base,base_uv,body,weights,mat,hidden)
    for name,(v,uv,f,w,h,material,directory) in parts:
        texture=directory/material['diffuseTexture'] if 'diffuseTexture' in material else None
        hair=name in ['short02','bob01']
        mat=model.material(name,texture,color=(0.25,0.22,0.20,1) if hair else (1,1,1,1),alpha=hair)
        model.mesh(name,v,uv,f,w,mat)
    # Eyeballs use the same attachment mapping as the clothing assets.
    try:
        file=find('low-poly.mhclo');v,uv,f,w,h,m,d=clothing(file,positive_skin=True)
        texture=find('brown_eye.png')
        model.mesh('eyes',v,uv,f,w,model.material('eyes',texture))
    except RuntimeError:pass
    model.save(OUTPUT/output)
    print(output, (OUTPUT/output).stat().st_size)

if __name__=='__main__':
    configure(Path(sys.argv[1]))
    OUTPUT.mkdir(parents=True,exist_ok=True)
    build('male_casualsuit01','casual.glb')
    build('male_elegantsuit01','office.glb')
    build('female_elegantsuit01','office_female.glb',True)
