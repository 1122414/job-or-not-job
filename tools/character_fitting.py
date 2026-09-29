"""Geometry corrections for the selected hm08 cast, in source mesh coordinates.

These are offline fitting operations, never runtime collision/IK substitutes.
"""

def front_triangles(vertices, faces, low_y, high_y):
    result=[]
    for group,face in faces:
        a,b,c=[vertices[i] for i,u in face]
        if max(a[1],b[1],c[1])<low_y or min(a[1],b[1],c[1])>high_y:
            continue
        denominator=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        # hm08 faces forward along +Z. Back of the head must not close the mouth.
        if denominator>1e-10:
            result.append((a,b,c,denominator))
    return result


def projected_weights(point, triangle):
    x,y=point[:2]
    a,b,c,denominator=triangle
    if x<min(a[0],b[0],c[0]) or x>max(a[0],b[0],c[0]) or y<min(a[1],b[1],c[1]) or y>max(a[1],b[1],c[1]):
        return None
    u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denominator
    v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denominator
    w=1.0-u-v
    return (u,v,w) if min(u,v,w)>=-1e-7 else None


def front_depth(point, triangles):
    result=None
    for triangle in triangles:
        weights=projected_weights(point,triangle)
        if weights is not None:
            z=sum(weight*v[2] for weight,v in zip(weights,triangle[:3]))
            result=z if result is None else max(result,z)
    return result


def bind_brows(vertices, body, faces, morphs, clearance):
    """Keep each brow point on its rest skin triangle throughout linear expressions."""
    low=min(v[1] for v in vertices); high=max(v[1] for v in vertices)
    surfaces=[]
    for item in faces:
        triangles=front_triangles(body,[item],low,high)
        if triangles: surfaces.append((triangles[0],[i for i,u in item[1]]))
    fitted=[]; shapes={name:{} for name in morphs}
    for vertex,point in enumerate(vertices):
        hits=[]
        for triangle,indices in surfaces:
            weights=projected_weights(point,triangle)
            if weights is not None:
                hits.append((sum(w*v[2] for w,v in zip(weights,triangle[:3])),indices,weights))
        if not hits: raise ValueError('Eyebrow vertex outside the selected face surface')
        z,indices,weights=max(hits,key=lambda hit:hit[0])
        fitted.append((point[0],point[1],z+clearance))
        for name,delta in morphs.items():
            shapes[name][vertex]=tuple(sum(w*delta.get(i,(0,0,0))[axis] for i,w in zip(indices,weights)) for axis in range(3))
    # A deep frown can fold a neighbouring skin triangle in front of the bound one.
    # Keep a local static envelope so interpolation does not pop between surfaces.
    lifts=[0.0]*len(fitted)
    for name,delta in morphs.items():
        posed=displace(fitted,shapes[name])
        triangles=front_triangles(displace(body,delta),faces,min(v[1] for v in posed),max(v[1] for v in posed))
        for i,point in enumerate(posed):
            z=front_depth(point,triangles)
            if z is not None: lifts[i]=max(lifts[i],z+clearance-point[2])
    fitted=[(v[0],v[1],v[2]+lifts[i]) for i,v in enumerate(fitted)]
    return fitted,shapes


def subdivide_attachment(vertices, uvs, faces, skin):
    """Split each triangle, preserving UV seams and skin weights before face binding."""
    vertices=list(vertices); uvs=list(uvs); skin=list(skin)
    edges={}; result=[]
    def midpoint(a,b):
        key=tuple(sorted((a,b)))
        if key not in edges:
            i,u=a; j,v=b
            vertex=len(vertices); uv=len(uvs)
            vertices.append(tuple((vertices[i][axis]+vertices[j][axis])/2 for axis in range(3)))
            uvs.append(tuple((uvs[u][axis]+uvs[v][axis])/2 for axis in range(2)))
            skin.append({bone:(skin[i].get(bone,0)+skin[j].get(bone,0))/2 for bone in skin[i].keys()|skin[j].keys()})
            edges[key]=(vertex,uv)
        return edges[key]
    for group,(a,b,c) in faces:
        ab=midpoint(a,b); bc=midpoint(b,c); ca=midpoint(c,a)
        result.extend((group,f) for f in [(a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)])
    return vertices,uvs,result,skin


def oral_faces(faces, uvs):
    # Select a complete UV island, not a rectangle that also clips neighbouring hands.
    parent={}
    def root(vertex):
        parent.setdefault(vertex,vertex)
        if parent[vertex]!=vertex: parent[vertex]=root(parent[vertex])
        return parent[vertex]
    for group,face in faces:
        for vertex,uv in face: parent[root(uv)]=root(face[0][1])
    islands={}
    for uv in parent: islands.setdefault(root(uv),set()).add(uv)
    matches=[ids for ids in islands.values() if min(uvs[u][0] for u in ids)>.75 and min(uvs[u][1] for u in ids)>.86 and max(uvs[u][0] for u in ids)>.9]
    if len(matches)!=1: raise ValueError('Expected one hm08 mouth UV island')
    selected=matches[0]
    oral=[]; outer=[]
    for item in faces:
        (oral if item[1][0][1] in selected else outer).append(item)
    return outer,oral


def contain_mouth(vertices, outer, oral, clearance, max_protrusion=float('inf')):
    rim={i for g,f in outer for i,u in f}
    interior={i for g,f in oral for i,u in f}-rim
    triangles=front_triangles(vertices,outer,min(vertices[i][1] for i in interior),max(vertices[i][1] for i in interior))
    result=list(vertices)
    for i in interior:
        x,y,z=vertices[i]
        surface=front_depth(vertices[i],triangles)
        if surface is not None and surface-clearance<z<surface+max_protrusion:
            result[i]=(x,y,surface-clearance)
    return result


def displace(vertices, deltas):
    return [tuple(v[a]+deltas.get(i,(0,0,0))[a] for a in range(3)) for i,v in enumerate(vertices)]


def difference(vertices, rest):
    return {i:tuple(v[a]-rest[i][a] for a in range(3)) for i,v in enumerate(vertices) if v!=rest[i]}
