module TestRewrite
using Test
using Catlab, Catlab.Theories
# once rewriting is removed from catlab, we can import the entire namespace
using Catlab.CategoricalAlgebra: ACSetTransformation, CSetTransformation, @acset_type, @acset, add_part!, add_parts!,nparts, ComposablePair, is_isomorphic, pushout, pullback, force, apex, rem_part!, Slice
using Catlab.Graphs, Catlab.WiringDiagrams, Catlab.Programs
using AlgebraicRewriting.FinSets: id_condition
using AlgebraicRewriting.CSets: dangling_condition
using AlgebraicRewriting
import AlgebraicRewriting: homomorphism, homomorphisms

# Slice
#######
two = @acset Graph begin V=2; E=2; src=[1,2]; tgt=[2,1] end
L_ = path_graph(Graph, 2)
L = Slice(ACSetTransformation(L_, two, V=[2,1], E=[2]))
I_ = Graph(1)
I = Slice(ACSetTransformation(I_, two, V=[2]))
R_ = Graph(2)
R = Slice(ACSetTransformation(R_, two, V=[2, 1]))

rule = Rule(homomorphism(I, L), homomorphism(I, R))
G_ = path_graph(Graph, 3)
G = Slice(ACSetTransformation(G_, two, V=[1,2,1], E=[1,2])) # (S) ⟶ [T] ⟶ (S)

H = rewrite(rule, G)


# Wiring diagrams
#################

@present Tst(FreeSymmetricMonoidalCategory) begin
  X::Ob
  (f,g,h)::Hom(X, X)
  i::Hom(X⊗X, X⊗X)
end

GWD = @program Tst (x::X,y::X) begin
  h(g(f(x))), f(y)
end

LWD = @program Tst (x::X) begin
  g(f(x))
  return ()
end
rem_wires!(LWD, -2, 1)
rem_part!(LWD.diagram, :OuterInPort, 1)

RWD = @program Tst (x::X) begin
  _, y = i(f(x),x)
  g(y)
  return ()
end
[rem_wires!(RWD, -2, i) for i in [1,2]]
rem_part!(RWD.diagram, :OuterInPort, 1)
add_wire!(RWD, (2,1)=>(2,2))

dtype = Catlab.WiringDiagrams.DirectedWiringDiagrams.WiringDiagramACSet{Any, Any, Any, DataType}

IWD = @program Tst (x::X) begin
  _, _ = f(x), g(x)
  return ()
end
[rem_wires!(IWD, -2, i) for i in [1,2]]
rem_part!(IWD.diagram, :OuterInPort, 1)

XWD = @program Tst (x::X,y::X) begin
  h(g(i(f(x),x)[2])), f(y)
end
rem_wires!(XWD, -2, 2)
add_wire!(XWD, (2,1)=>(2,2))

L=homomorphism(IWD.diagram, LWD.diagram)
R=homomorphism(IWD.diagram, RWD.diagram)
m=homomorphism(LWD.diagram, GWD.diagram)
rewrite(Rule(L,R), GWD.diagram)
@test is_isomorphic(XWD.diagram, rewrite_match(Rule(L,R), m))


IWD.diagram
# Graphs with attributes
########################

@present TheoryDecGraph(FreeSchema) begin
  E::Ob
  V::Ob
  src::Hom(E,V)
  tgt::Hom(E,V)

  X::AttrType
  dec::Attr(E,X)
end

@present TheoryLabeledDecGraph <: TheoryDecGraph begin
  label::Attr(V,X)
end

@acset_type LabeledDecGraph(TheoryLabeledDecGraph, index=[:src,:tgt])

aI2 = @acset LabeledDecGraph{String} begin
  V = 2;  label = ["a","b"]
end

aarr = @acset LabeledDecGraph{String} begin
  V=2;  E=1;  src=1; tgt=2
  dec = ["e1"];  label = ["a","b"]
end

abiarr = @acset LabeledDecGraph{String} begin
  V = 2; E = 2; src = [1,2]; tgt = [2,1]
  dec = ["e1","rev_e1"]; label = ["a","b"]
end

aspan = @acset LabeledDecGraph{String} begin
  V = 3; E = 2; src = [1,1];  tgt = [2,3]
  dec = ["e1","e2"];  label = ["a","b","c"]
end

expected = @acset LabeledDecGraph{String} begin
  V = 3
  E = 3
  src = [1,1,2]
  tgt = [2,3,1]
  dec = ["e1","e2","rev_e1"]
  label = ["a","b","c"]
end


L = ACSetTransformation(aI2, aarr, V=[1,2]);
R = ACSetTransformation(aI2, abiarr, V=[1,2]);
m = ACSetTransformation(aarr, aspan, V=[2,1], E=[1]);  # sends 'a'->'b' and 'b'->'a'

@test_throws ErrorException("ACSet colimit does not exist: label attributes a != b") rewrite_match(Rule(L,R),m)

m = ACSetTransformation(aarr, aspan, V=[1,2], E=[1]);

@test is_isomorphic(expected, rewrite_match(Rule(L, R), m))

# Graphs
########

# Example graphs
I2 = Graph(2)
I3 = Graph(3)
#   e1   e2
# 1 <- 2 -> 3
span = @acset Graph begin V=3;E=2;src=[2,2];tgt=[1,3] end
# 1 -> 2
arr = path_graph(Graph, 2)
# 1 <-> 2
biarr = @acset Graph begin V=2; E=2; src=[1,2]; tgt=[2,1] end
# 1 -> 2 -> 3 -> 1
tri = cycle_graph(Graph, 3)
# 4 <- 1 -> 2 and 2 <- 3 -> 4
dispan = @acset Graph begin V=4; E=4; src= [1,1,3,3]; tgt=[2,4,2,4] end

#      e1
#    1 -> 2
# e2 |  / ^
#    vv   | e4
#    4 -> 3
#      e5
squarediag = Graph(4)
add_edges!(squarediag, [1,1,2,3,4],[2,4,4,2,3])

# Add a reverse arrow to span
span_w_arrow = Graph(3)
add_edges!(span_w_arrow,[1,1,2],[2,3,1])

L = CSetTransformation(I2, arr, V=[1,2])
R = CSetTransformation(I2, biarr, V=[1,2])
m = CSetTransformation(arr, span, V=[2,1], E=[1])
@test is_isomorphic(span_w_arrow, rewrite_match(Rule(L, R), m))

# Remove apex of a subspan (top left corner of squarediag, leaves the triangle behind)
L = CSetTransformation(I2, span, V=[1,3])
m = CSetTransformation(span, squarediag, V=[2,1,4], E=[1,2])
@test is_isomorphic(tri, rewrite_match(Rule(L,id(I2)),m))

# Remove self-edge using a *non-monic* match morphism
two_loops = Graph(2)
add_edges!(two_loops,[1,2],[1,2]) # ↻1   2↺
one_loop = Graph(2)
add_edges!(one_loop,[2],[2]) # 1   2↺

L = CSetTransformation(I2, arr, V=[1,2])
m = CSetTransformation(arr, two_loops, V=[1, 1], E=[1])
@test is_isomorphic(one_loop, rewrite_match(Rule(L,id(I2)),m))

# Simplest non-trivial, non-monic exmaple
@present TheoryFinSet(FreeSchema) begin
  X::Ob
end
@acset_type FinSetType(TheoryFinSet)

I, L, G = [@acset FinSetType begin X=i end for i in [2,1,1]]
l = CSetTransformation(I, L, X=[1,1])
m = CSetTransformation(L, G, X=[1])
@test can_pushout_complement(ComposablePair(l,m))
ik, kg = pushout_complement(ComposablePair(l,m))
# There are 3 functions `ik` that make this a valid P.C.
# codom=1 with [1,1], codom=2 with [1,2] or [2,1]
K = codom(ik)
@test nparts(K, :X) == 1 # algorithm currently picks the first option

# Non-discrete interface graph. Non-monic matching
arr_loop= @acset Graph begin V=2; E=2; src=[1,2]; tgt=[2,2] end  # 1->2↺
arrarr = @acset Graph begin V=2; E=2; src=[1,1]; tgt=[2,2] end #  1⇉2
arrarr_loop = @acset Graph begin V=2; E=3; src=[1,1,2]; tgt=[2,2,2] end # 1⇉2↺
arr_looploop = @acset Graph begin V=2;E=3; src= [1,2,2]; tgt=[2,2,2]end # 1-> ↻2↺

L = CSetTransformation(arr, arr, V=[1,2],E=[1]) # identity
R = CSetTransformation(arr, arrarr, V=[1,2], E=[1])
m = CSetTransformation(arr, arr_loop, V=[2,2], E=[2]) # NOT MONIC
@test is_isomorphic(arr_looploop, rewrite_match(Rule(L,R),m))

# only one monic match
@test is_isomorphic(arrarr_loop, rewrite(Rule(L, R; monic=true), arr_loop))

# two possible morphisms L -> squarediag, but both violate dangling condition
L = CSetTransformation(arr, span, V=[1,2], E=[1]);
m = CSetTransformation(span, squarediag, V=[2,1,4], E=[1,2]);
@test (:src, 5, 4) in dangling_condition(ComposablePair(L,m))

# violate id condition because two orphans map to same point
L = CSetTransformation(I2, biarr, V=[1,2]); # delete both arrows
m = CSetTransformation(biarr, arr_loop, V=[2,2], E=[2,2]);
@test (1, 2) in id_condition(ComposablePair(L[:E],m[:E]))[2]
L = CSetTransformation(arr, biarr, V=[1,2], E=[1]); # delete one arrow
@test 1 in id_condition(ComposablePair(L[:E],m[:E]))[1]

span_triangle = @acset Graph begin V=3; E=3; src=[1,1,2];tgt= [2,3,3]end;# 2 <- 1 -> 3 (with edge 2->3)

L = CSetTransformation(arr, tri, V=[1,2], E=[1]);
m = CSetTransformation(tri, squarediag, V=[2,4,3], E=[3,5,4]);
@test is_isomorphic(span_triangle, rewrite_match(Rule(L,id(arr)),m))

k, g = pushout_complement(ComposablePair(L, m)); # get PO complement to do further tests

# the graph interface is equal to the final graph b/c we only delete things
@test is_isomorphic(span_triangle, codom(k))

# Check pushout properties 1: apex is the original graph
@test is_isomorphic(squarediag, ob(pushout(L, k))) # recover original graph

# Check pushout properties 2: the diagram commutes
Lm = compose(L,m);
kg = compose(k,g);
for I_node in 1:2
  @test Lm[:V](I_node) == kg[:V](I_node)
end
@test Lm[:E](1) == kg[:E](1)

# Check pushout properties 3: for every pair of unmatched things between K and L, they are NOT equal
for K_node in 1:3
  @test m[:V](3) != g[:V](K_node)
end

for K_edge in 2:3
  @test m[:E](3) != g[:E](K_edge)
end

# Undirected bipartite graphs
#############################

# 1 --- 1
#    /
# 2 --- 2

z_ = @acset UndirectedBipartiteGraph begin
  V₁=2; V₂=2; E=3; src= [1,2,2]; tgt= [1,1,2]
end

line = UndirectedBipartiteGraph()
add_vertices₁!(line, 1)
add_vertices₂!(line, 2)
add_edges!(line, [1], [1])

parallel = UndirectedBipartiteGraph()
add_vertices₁!(parallel, 2)
add_vertices₂!(parallel, 2)
add_edges!(parallel, [1,2], [1,2])

merge = UndirectedBipartiteGraph()
add_vertices₁!(merge, 2)
add_vertices₂!(merge, 2)
add_edges!(merge, [1,2], [1,1])

Lspan = UndirectedBipartiteGraph()
add_vertices₁!(Lspan, 1)
add_vertices₂!(Lspan, 2)
add_edges!(Lspan, [1,1],[1,2])

I = UndirectedBipartiteGraph()
add_vertices₁!(I, 1)
add_vertices₂!(I, 2)

L = CSetTransformation(I, Lspan, V₁=[1], V₂=[1,2])
R = CSetTransformation(I, line, V₁=[1], V₂=[1,2])
m1 = CSetTransformation(Lspan, z_, V₁=[1], V₂=[1,2], E=[1, 2])
m2 = CSetTransformation(Lspan, z_, V₁=[1], V₂=[2,1], E=[2, 1])

@test is_isomorphic(parallel, rewrite_match(Rule(L, R), m1))
@test is_isomorphic(merge, rewrite_match(Rule(L, R), m2))

# Sesqui Pushout Tests
######################

# partial map classifier test
#############################
A = star_graph(Graph, 4)
X = path_graph(Graph, 2)
B = @acset Graph begin V = 1; E = 1; src=[1]; tgt=[1] end
m = CSetTransformation(X,A,V=[4,1],E=[1])
f = CSetTransformation(X,B,V=[1,1],E=[1])
phi = partial_map_classifier_universal_property(m,f)

# check pullback property
m_, f_ = pullback(phi, partial_map_classifier_eta(B)).cone

# This is isomorphic, but it's a particular implementation detail which
# isomorphism is produced. At the time of writing this test, it turns out we get
# an identical span if we reverse the arrow of the apex X
iso = CSetTransformation(X,X;V=[2,1], E=[1])
@test force(compose(iso, m_)) == m
@test force(compose(iso, f_)) == f

# Another test
#------------
loop = @acset Graph begin
  V=1; E=1; src=[1]; tgt=[1] end
fromLoop = @acset Graph begin
  V=2; E=2; src=[1,1]; tgt=[2,1] end
toLoop = @acset Graph begin
  V=2; E=2; src=[1,2]; tgt=[2,2] end
f = CSetTransformation(loop, fromLoop, V=[1],E=[2])
m = CSetTransformation(loop, toLoop, V=[2],E=[2])
u = partial_map_classifier_universal_property(m,f)
m_,f_ = pullback(u, partial_map_classifier_eta(codom(f))).cone
@test force.([m_,f_]) == [m,f]


# Final pullback complement test
################################
A, B, C = Graph(2), Graph(1), path_graph(Graph, 2)
f = CSetTransformation(A,B;V=[1,1])
m = CSetTransformation(B,C; V=[2])

fpc = final_pullback_complement(ComposablePair(f,m))

# Sesqui-pushout rewriting
###########################
# Examples from Corradini (2006) access control model

# (Figure 3) Clone a node that points to other things
# resulting in the copies both sharing what they point to
#----------------------------------------------------------
L, I, R = Graph.([1,2,2])
G = @acset Graph begin V=3; E=2; src=1; tgt=[2,3] end
m = CSetTransformation(L, G; V=[1])
l = CSetTransformation(I, L; V=[1,1])
r = id(I)

rw = rewrite_match(Rule{:SqPO}(l, r), m)
@test is_isomorphic(rw, @acset Graph begin
  V=4; E=4; src=[1,1,2,2]; tgt=[3,4,3,4] end)

# (Figure 2) Another example that's nondeterministic for DPO
# category of simple graphs is quasi-adhesive, and uniqueness of
# pushout complements is guaranteed along regular monos only, i.e., morphisms
# reflecting edges: but this l morphism is not regular.
L, I, R = path_graph(Graph, 2), Graph(2), Graph(2)
G = @acset Graph begin V=3; E=3; src=1; tgt=[2,2,3] end
l, r = CSetTransformation(I, L; V=[1,2]), id(I)
m = CSetTransformation(L, G; V=[1,2], E=[1])
rw = rewrite_match(Rule{:SqPO}(l,r), m)
@test is_isomorphic(rw, @acset Graph begin V=3; E=2; src=1; tgt=[2,3] end)

# (Figure 1) Example that would be dangling condition violation for DPO
# However, SqPO deletes greedily
G= @acset Graph begin V=4; E=3; src=[1,3,3]; tgt=[2,2,4] end
L,I,R = Graph.([1,0,0])
l, r = CSetTransformation(I,L), CSetTransformation(I,R)
m = CSetTransformation(L, G; V=[3])
rw = rewrite_match(Rule{:SqPO}(l,r), m)
@test is_isomorphic(rw, @acset Graph begin V=3; E=1; src=1; tgt=2 end)

# Pullback complement
#--------------------
G3, G5, G4 = Graph.([3,5,4])
G35 = CSetTransformation(G3, G5; V=[1,2,3])
G54 = CSetTransformation(G5, G4; V=[1,1,2,3,4])
ad,dc = pullback_complement(G35,G54)


A = path_graph(Graph, 3);
K = path_graph(Graph, 2);
B = path_graph(Graph, 2);
add_edge!(B, 2, 2);
C = path_graph(Graph, 4);
add_edge!(C, 1, 3);
ka = path_graph(Graph, 2);
ka, kb = [CSetTransformation(K, x, V=[1,2], E=[1]) for x in [A,B]];
ac = CSetTransformation(A, C, V=[1,2,3], E=[1,2]);

spr = rewrite_match(Rule{:SPO}(ka,kb), ac)
@test is_isomorphic(spr, @acset Graph begin V=3; E=2; src=[1,2]; tgt=2 end)

# Semisimplicial sets
#####################
@present ThSemisimplicialSet(FreeSchema) begin
  (V,E,T) :: Ob
  (d1,d2,d3)::Hom(T,E)
  (src,tgt) :: Hom(E,V)
  compose(d1, src) == compose(d2, src)
  compose(d1, tgt) == compose(d3, tgt)
  compose(d2, tgt) == compose(d3, src)
end
@acset_type SSet(ThSemisimplicialSet)

quadrangle = @acset SSet begin
    T=2; E=5; V=4
    d1=[1,1]
    d2=[2,3]
    d3=[4,5]
    src=[1,1,1,2,3]
    tgt=[4,2,3,4,4]
end

L = quadrangle  # We defined quadrilateral above.
I = @acset SSet begin
  E=4; V=4
  src=[1,1,2,3]
  tgt=[2,3,4,4]
end
R = @acset SSet begin
  T=2; E=5; V=4
  d1=[2,3]
  d2=[1,5]
  d3=[5,4]
  src=[1,1,2,3,2]
  tgt=[2,3,4,4,3]
end
edge = @acset SSet begin E=1; V=2; src=[1]; tgt=[2] end
edge_left = homomorphism(edge, L; initial=Dict([:V=>[1,3]]))
edge_left_R = homomorphism(edge, R; initial=Dict([:V=>[1,3]]))
edge_right = homomorphism(edge, L; initial=Dict([:V=>[2,4]]))
G = apex(pushout(edge_left, edge_right))
r = Rule(homomorphism(I, L; monic=true), homomorphism(I, R; monic=true);
         monic=true)
res =  rewrite(r, G)
expected = apex(pushout(edge_left_R, edge_right))
@test !is_isomorphic(res, G) # it changed
@test is_isomorphic(res, expected)

Tri = @acset SSet begin
  T=1; E=3; V=3;
  d1=[1]; d2=[2]; d3=[3];
  src=[1,1,2]; tgt=[3,2,3]
end

r = Rule{:SPO}(homomorphisms(edge, Tri)[2], id(edge))
r_dpo = Rule(r.L, r.R)

m = homomorphism(Tri, quadrangle)

# This does not make sense for DPO
@test !can_pushout_complement(ComposablePair(r.L, m))
@test_throws ErrorException rewrite_match_maps(r_dpo, m; check=true)
@test is_isomorphic(rewrite_match(r,m),
                    @acset SSet begin E=2; V=3; src=1; tgt=[2,3] end)

L = @acset SSet begin V=1 end
I = @acset SSet begin V=2 end
r =Rule{:SqPO}(homomorphism(I,L),id(I))
m = CSetTransformation(L, Tri, V=[1]);
# We get 4 'triangles' when we ignore equations
@test nparts(rewrite_match(r, m), :T) == 4

resSqPO= rewrite_match(r, m; pres=ThSemisimplicialSet) # pass in the equations
@test nparts(resSqPO, :T) == 2 # the right number of triangles

# Negative application conditions
#################################
#(using the same l as example immediately above)

L = @acset Graph begin V=3; E=2; src=1; tgt=[2,3] end
l = homomorphism(Graph(3), L; monic=true); R=id(Graph(3))
r = id(Graph(3))
N = @acset Graph begin V=3; E=4; src=[1,1,2,3]; tgt=[2,3,2,3] end
n = homomorphism(L,N; monic=true)
G = @acset Graph begin V=4; E=6; src=[1,1,1,2,3,4]; tgt=[2,3,4,2,3,4] end
@test rewrite_parallel(Rule(l,r,n; monic=true), G) === nothing
@test rewrite_parallel(Rule(l,r,[NAC(n)]; monic=true), G) === nothing


# Positive application conditions
#################################
g1, t = Graph(1), apex(terminal(Graph))
g1_t = homomorphism(g1, t)
r = Rule(id(g1), g1_t)
@test rewrite(r, g1) == t
r = Rule(id(g1), g1_t, [PAC(g1_t)])
@test isnothing(rewrite(r, g1))
@test rewrite(r, t) == @acset Graph begin V=1; E=2; src=1; tgt=1 end

end # module
