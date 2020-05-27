(* ::Package:: *)

(* ::Section:: *)
(*Begin*)


BeginPackage["mixonBasisCode`"]


computeMixonBasis::usage=
"computeMixonBasis[\[CapitalDelta]max,basisBoson,basisFermion,(optional) SUSY->False]
computes the mixon basis using the double trace construction from
the calculated boson basis, basisBoson, and fermion basis ,basisFermion.

- \[CapitalDelta]max is the maximum scaling dimension of the basis states. 
- basisBoson is the scalar basis generated by ScalarBasis.wl
- basisFermion is the fermion basis generated by FermionBasis.wl
- If set SUSY->True, then truncate the scalar and fermion at the same degree. 
Effectively this takes the dimension of \[PartialD]\[Psi] to be 1 when counting the dimension 
for truncation. (Default False)

Note that the \[CapitalDelta]max argument should be the same as the \[CapitalDelta]max argument 
used to generate the basisBoson and basisFermion, or exceptions
may occur. Also SUSY option needs to be the same as the one used to 
generate basisFermion.

-------------

The output of the file is basisMixon, which contains all basis 
grouped according to their quantum numbers:
- First, the states are specified by the number of scalars, nB, and the 
number of fermions, nF. For each pair of (nB,nF), basisMixon[[nB+1,nF+1]] 
contains all such states.
- basisMixon[[nB+1,nF+1]] itself is a 1D-list containing Associations,
each association is specified by three more numbers:
	- The degree of the scalar component, degB
	- The degree of the fermion component, degF
	- The number derivatives acting between the scalar primary operator
	and the fermion primary operator, l
- For each association specified by (nB,nF,degB,degF,l), the key \"states\" 
extracts the list of all orthogonal states in this association.
- For each state in the list, it is specified by a list of (l+1) blocks of 
coefficients of monomials of the form 
	( \[PartialD]^m (\[Phi] monomials) *  \[PartialD]^(l-m) (\[Psi] monomials) ) 
with m running from 0 to l.
- Each block is an 2D-array of coefficients, which multiplies site-by-site
to the 2D-array of monomials, schematically, for the m-th block:
	outer_product( \[PartialD]^m (\[Phi] monomials), \[PartialD]^(l-m) (\[Psi] monomials) )
where \[PartialD]^m (\[Phi] monomials) monomials are generated by monomialsBoson[nB,degB+m],
and \[PartialD]^(l-m) (\[Psi] monomials) monomials are generated by monomialsFermion[nF,degF+l-m]
"


basisMixon::usage


Begin["`Private`"]


(* ::Section:: *)
(*External function*)


computeMixonBasis[\[CapitalDelta]max_,basisBoson_,basisFermion_,OptionsPattern[]]:=Block[
	{primaryStates,t1=AbsoluteTime[]},
	(* If we want to preserve SUSY, we need to truncate the scalar and fermion
	at the same degree. This is done by treating the dimension of \[PartialD]\[Psi] = \[CapitalDelta]f=1. 
	Otherwise dimension of \[PartialD]\[Psi] = \[CapitalDelta]f=3/2 *)
	If[OptionValue[SUSY],\[CapitalDelta]f=1,\[CapitalDelta]f=3/2];
	
	Print["@ : taking boson descendants"];
	takeBosonDescendants[\[CapitalDelta]max,basisBoson];
	Print["Time (s):", (AbsoluteTime[]-t1)];
	
	Print["@ : taking fermion descendants"];
	takeFermionDescendants[\[CapitalDelta]max,basisFermion];
	Print["Time (s):", (AbsoluteTime[]-t1)];
	
	Print["@ : gluing fermion and bosons"];
	basisMixon=Join[
		(* The purely scalar states *)
		Reap[Do[(* for nF=0, run nB from 0 to maximum *)
			(* primaryStates is the scalar states at the level (deg,n) *)
			primaryStates=basisBoson[[1,deg+1,n]];
			(* If primaryStates is empty then the level is skipped. 
			If not then send the state to the nB=n, degB=deg, nF=0, degF=0, l=0 sector.
			Since the state has no fermions, one can think of the monomials as scalar monomials times 1.
			Thus the coefficient array is the scalar Kronecker Product with {1} *)
			If[primaryStates!={}, Sow[{KroneckerProduct[#,{1}]},state[n,deg,0,0,0]]&/@primaryStates],
			{deg,0,\[CapitalDelta]max},{n,1,\[CapitalDelta]max-deg}
		],state[__],<|Thread[{"nB","degB","nF","degF","l"}->List@@#1],"states"->#2|>&][[2]] ,
		
		(* The purely fermion states *)
		Reap[Do[(* for nB=0, run nF from 0 to maximum *)
			primaryStates=basisFermion[[1,deg+1,n]];
			(* If primaryStates is empty then the level is skipped. 
			If not then send the state to the nB=0, degB=0, nF=n, degF=deg, l=0 sector.
			Since the state has no scalar, one can think of the monomials as fermion monomials times 1.
			Thus the coefficient array is the scalar Kronecker Product with {1} *)
			If[primaryStates!={}, Sow[{KroneckerProduct[{1},#]},state[0,0,n,deg,0]]&/@primaryStates],
			{deg,0,\[CapitalDelta]max},{n,1,Floor[(\[CapitalDelta]max-deg)/\[CapitalDelta]f]}
		],state[__],<|Thread[{"nB","degB","nF","degF","l"}->List@@#1],"states"->#2|>&][[2]] ,
		
		(* For nB and nF both nonzero, one obtains mixon primary states from the double trace 
		construction of each pairs of scalar operator and fermion operator *)
		glueBosonsAndFermions[\[CapitalDelta]max]
	];
	(* Collect the states into an array basisMixon[[degB+1,degF+1]] *)
	basisMixon=GatherBy[SortBy[basisMixon,{#nB&,#nF&,#degB&,#degF&,#l&}],{#nB&,#nF&}];
	basisMixon=Insert[basisMixon,{},{1,1}];
	basisMixon=With[{maxNFPlus1=(Length/@basisMixon)//Max},
		PadRight[#,maxNFPlus1,{{}}]&/@basisMixon
	];
	
	Print["Time (s):", (AbsoluteTime[]-t1)];
	
];
Options[computeMixonBasis]={SUSY->False}


(* ::Section:: *)
(*Compute*)


(* ::Subsection:: *)
(*take boson descendants*)


(*
	takeBosonDescendants[\[CapitalDelta]max_,basisBoson_] 
	gives the complete list of all scalar primary states and their descendents below 
	\[CapitalDelta]max.
	The output is specified by the degree, deg, of the primary and number of 
	scalars, n, and number of derivative, m,
	result[[deg+1,n,m+1]] is a list of states \[PartialD]^m V where V is a list of all primary
	states at (n,deg).
*)
takeBosonDescendants[\[CapitalDelta]max_,basisBoson_]:=Block[
	{primaryStates},
	bosonBasisWithDescendants=Table[
		(* extract all states at level (deg,n) *)
		primaryStates=basisBoson[[1,deg+1,n]];
		If[primaryStates=={},{},MapThread[
			Function[{states,norm},Map[#*norm&,states]],
			{
				(* Recursively take derivatives of states in primaryStates to obtain
				all descendents up to \[CapitalDelta]max. *)
				FoldList[
					(* For a list of operators, V={op1,op2,op3...}, 
					V.dBoson[n,deg] gives a list of their descendents.
					The degree will increase by 1. *)
					#1.dBoson[n,#2]&,
					(* dBoson[n,deg] acts on vectors of C_O^k, and what's stored in
					primaryStates are C_O^k*factors[k], so that factor needs to be
					divided first. Then we can act dBoson[] on the vectors. *)
					(#/factorBosonAtLevel[n,deg])&/@primaryStates,
					(* Each time taking a derivative adds degree by 1, so the second
					argument of dBoson[.,degree] has to increase by 1 each time, going
					from deg to \[CapitalDelta]max-n-\[CapitalDelta]f. *)
					Range[deg,\[CapitalDelta]max-n-\[CapitalDelta]f,1]
				],
				(* Multiply back the factors[k] *)
				factorBosonAtLevel[n,#]&/@Prepend[Range[deg+1,\[CapitalDelta]max-n-\[CapitalDelta]f+1,1],deg]
			}
		] ],
		{deg,0,\[CapitalDelta]max},{n,1,\[CapitalDelta]max-deg}
	]
];


(*
dBoson[n,deg] computes the action of taking the derivative of a 
polynomial state at level (n,deg) as a linear map between the space 
of monimials at level (n,deg) to the space of monimials at level 
(n,deg+1).
The output of dBoson[n,deg] is a matrix. For a state of or a list of 
states, V, 
V.dBoson[n,deg]
is the (list of) derivative state(s) in the target monomial space.
*)
ClearAll[dBoson]
dBoson[n_,deg_]:=dBoson[n,deg]=Block[
	{aUp,aLow,map,mat,ap},
	(* Map the monomials to the occupation number representation *)
	aLow=cfBinCount[#,deg+2]&/@monomialsBoson[n,deg];
	aUp=cfBinCount[#,deg+2]&/@monomialsBoson[n,deg+1];
	(* Map each monomial to its index of the vector in the target 
	monomial space, and save it as the map function *)
	MapThread[(map[#1]=#2)&,{aUp,Range[Length[aUp]]}];
	(* mat is the output matrix *)
	mat=SparseArray[{},{aLow//Length,aUp//Length}];
	(* 
	For each monomial a in aLow, 
		for each non-zero occupation number a[[#]], hit it with a derivative,
		and the resulting monomial is ap, which:
			ap[[#]] = a[[#]]-1
			a[[#+1]] = a[[#+1]]+1
	then add up all results ap. Store the transition coefficients in mat.
	*)
	Do[With[{a=aLow[[i]]},
		(mat[[i,map[
			ap=a;ap[[#]]-=1;ap[[#+1]]++;ap
		  ]  ]]+=a[[#]]) &/@
			Flatten[Position[a,_?Positive,1]]
	],{i,Length[aLow]}];
	mat
]


(* ::Subsection:: *)
(*take fermion descendants*)


(*
	takeFermionDescendants[\[CapitalDelta]max_,basisFermion_] 
	gives the complete list of all fermion primary states and their descendents below 
	\[CapitalDelta]max.
	The output is specified by the degree, deg, of the primary and number of 
	fermions, n, and number of derivative, m,
	result[[deg+1,n,m+1]] is a list of states \[PartialD]^m V where V is a list of all primary
	states at (n,deg).
*)
takeFermionDescendants[\[CapitalDelta]max_,basisFermion_]:=Block[
	{primaryStates},
	fermionBasisWithDescendants=Table[
	(* extract all states at level (deg,n) *)
	primaryStates=basisFermion[[1,deg+1,n]];
		If[primaryStates=={},{},MapThread[
			Function[{states,norm},Map[#*norm&,states]],
			{
				(* Recursively take derivatives of states in primaryStates to obtain
				all descendents up to \[CapitalDelta]max. *)
				FoldList[
					(* For a list of operators, V={op1,op2,op3...}, 
					V.dFermion[n,deg] gives a list of their descendents.
					The degree will increase by 1. *)
					#1.dFermion[n,#2]&,
					(* dFermion[n,deg] acts on vectors of C_O^k, and what's stored in
					primaryStates are C_O^k*factorFermion[k], so that factor needs to be
					divided first. Then we can act dFermion[] on the vectors. *)
					(#/factorFermionAtLevel[n,deg])&/@primaryStates,
					(* Each time taking a derivative adds degree by 1, so the second
					argument of dFermion[.,degree] has to increase by 1 each time, going
					from deg to \[CapitalDelta]max-n*\[CapitalDelta]f-1. *)
					Range[deg,\[CapitalDelta]max-n*\[CapitalDelta]f-1,1]
				],
				(* Multiply back the factorFermion[k] *)
				factorFermionAtLevel[n,#]&/@Prepend[Range[deg+1,\[CapitalDelta]max-n*\[CapitalDelta]f-1+1,1],deg]
			}
		] ],
		{deg,0,\[CapitalDelta]max},{n,1,Floor[(\[CapitalDelta]max-deg)/\[CapitalDelta]f]}(* pretend the fermion \[PartialD]\[Psi] has dim=\[CapitalDelta]f *)
	]
];


(*
dFermion[n,deg] computes the action of taking the derivative of a 
polynomial state at level (n,deg) as a linear map between the space 
of monimials at level (n,deg) to the space of monimials at level 
(n,deg+1).
The output of dFermion[n,deg] is a matrix. For a state of or a list of 
states, V, 
V.dFermion[n,deg]
is the (list of) derivative state(s) in the target monomial space.
*)
ClearAll[dFermion]
dFermion[n_,deg_]:=(*dFermion[n,deg]=*)Block[
	{bDeg=deg+n-n (n+1)/2,
		kLow,kUp,
		aLow,aUp,
		map,mat,ap(*,eUp*)
	},
	(* kLow=monomialsBoson[n,bDeg]-1;
	kUp=monomialsBoson[n,bDeg+1]-1; *)
	(* Map the monomials to the occupation number representation *)
	aLow=cfBinCount[#,bDeg+2]&/@monomialsBoson[n,bDeg];
	aUp=cfBinCount[#,bDeg+2]&/@monomialsBoson[n,bDeg+1];
	(*eUp=bosonEncode/@kUp;*)
	(*MapThread[(map[#1]=#2)&,{eUp,Range[Length[eUp]]}];*)
	(* Map each monomial to its index of the vector in the target 
	monomial space, and save it as the map function *)
	MapThread[(map[#1]=#2)&,{aUp,Range[Length[aUp]]}];
	(* mat is the output matrix *)
	mat=SparseArray[{},{aLow//Length,aUp//Length}];
	(* 
	For each monomial a in aLow, 
		for each non-zero occupation number a[[#]], hit it with a derivative,
		and the resulting monomial is ap, which:
			ap[[#]] = a[[#]]-1
			a[[#+1]] = a[[#+1]]+1
	then add up all results ap. Store the transition coefficients in mat.
	*)
	Do[With[{a=aLow[[i]]},
		(mat[[i,map[
			ap=a;ap[[#]]-=1;ap[[#+1]]++;ap
		  ]  ]]+=1) &/@
			Flatten[Position[a,_?Positive,1]]
	],{i,Length[aLow]}];
	mat
]


(* ::Subsection:: *)
(*glue bosons and fermions*)


(* Normalize the vector v by dividing Sqrt[v.v] *)
normalize=(#/Sqrt[Total[Flatten[#]^2]]&)


(* glueBosonsAndFermions[\[CapitalDelta]max_,\[CapitalDelta]f_] takes the double trace construction
c_m \[PartialD]^m B \[PartialD]^(l-m) F 
where B is a scalar primary state and F is a fermion primary state.
  *)
glueBosonsAndFermions[\[CapitalDelta]max_]:=Block[
	{\[CapitalDelta]B,\[CapitalDelta]F,lMax},
	Reap[Do[
		\[CapitalDelta]B=degB+nB;
		\[CapitalDelta]F=degF+3/2*nF;(* This \[CapitalDelta]F enters the PrimCoeffs[\[CapitalDelta]B,\[CapitalDelta]F,l,k] coefficient, it has
		to be the true fermion operator's dimension, not the fictitious \[CapitalDelta]f. *)
		lMax=Floor[\[CapitalDelta]max-(degB+nB)-(degF+\[CapitalDelta]f*nF)];(* This counts the maximum derivatives 
		in the double trace construction between scalar primary B and fermion primary F. 
		We pretend the fermion \[PartialD]\[Psi] has dim=\[CapitalDelta]f. *)
		
		(* The coefficients of the mononials ( \[PartialD]^m (\[Phi] monomials) *  \[PartialD]^(l-m) (\[Psi] monomials) )
		are obtained from taking the outer product of the list of coefficients of the 
		\[PartialD]^m (\[Phi] monomials) and the list of coefficients of the \[PartialD]^(l-m) (\[Psi] monomials) *)
		Outer[
			Do[Sow[
				normalize@Table[PrimCoeffs[\[CapitalDelta]B,\[CapitalDelta]F,l,k]*KroneckerProduct[#1[[k+1]] ,#2[[l-k+1]]],{k,0,l}],
			state[nB,degB,nF,degF,l]],{l,0,lMax}]&,
			(* If either scalar states set or fermion states set is empty, then this level is skipped. *)
			If[#!={},Transpose[#],Continue[]]&@bosonBasisWithDescendants[[degB+1,nB]],
			If[#!={},Transpose[#],Continue[]]&@fermionBasisWithDescendants[[degF+1,nF]],
		1],
		{degB,0,\[CapitalDelta]max},
		{nB,1,\[CapitalDelta]max-degB},
		{degF,0,\[CapitalDelta]max-degB-nB},
		{nF,1,Floor[(\[CapitalDelta]max-degB-nB-degF)/\[CapitalDelta]f]}(* pretend the fermion \[PartialD]\[Psi] has dim=\[CapitalDelta]f *)
	(* Wrap the state by Association[.] *)
	],state[__],<|Thread[{"nB","degB","nF","degF","l"}->List@@#1],"states"->#2|>&][[2]] 
];


(* ::Section:: *)
(*Utility functions*)


(* ::Subsection:: *)
(*bin counting*)


(* 
	c = cfBinCount[k vector] computes the bin counts of vector \vec{k} so that
	for each k in \vec{k} the k'th element of c, c[[k]] is the number of copies
	of k in \vec{k}. If \vec{k} does not have k, then c[[k]]=0.

	One can use this function to generate bin counts of a monomial \vec{k} to
	send in yukawa[]. The function does not care whether the k vector comes from
	the scalar or fermion sector. So one has to separate the monomial into scalar
	monomial times fermion monomial and bin count separately.
 *)
cfBinCount=Compile[
	{{k,_Integer,1},{max,_Integer}},
	Module[
		{lst},
		lst=Table[0,{max}];
		Scan[
			lst[[#]]++&,k
		];
		lst
	],
	CompilationTarget->"C"
];


(* ::Subsection:: *)
(*monomial vectors*)


(* The list monomials at each level. The order of monomials defines
the index of each monomial in the target vector space. *)
ClearAll[monomialsBoson]
monomialsBoson[n_,deg_]:=monomialsBoson[n,deg]=IntegerPartitions[deg+n,{n}];
ClearAll[monomialsFermion]
monomialsFermion[n_,deg_]:=monomialsFermion[n,deg]=(#+Reverse[Range[n]-1])&/@monomialsBoson[n,deg+n-n (n+1)/2]


(* ::Subsection:: *)
(*state normalization factors*)


(* The normalization of the scalar primary states *)
ClearAll[factorBosonAtLevel]
factorBosonAtLevel[n_,deg_]:=factorBosonAtLevel[n,deg]=factorBoson/@IntegerPartitions[n+deg,{n}];
factorBoson[y_List]:=Sqrt[Times@@(#[[2]]!* #[[1]]^#[[2]]&/@Tally[y])]Times@@(Gamma/@y);


(* The normalization of the scalar primary states *)
ClearAll[factorFermionAtLevel]
factorFermionAtLevel[n_,deg_]:=factorFermionAtLevel[n,deg]=factorFermion/@Select[IntegerPartitions[n+deg,{n}],DuplicateFreeQ];
factorFermion[k_List]:=(Times@@(Gamma/@k)) * Sqrt[Times@@(1/2 * k*(k+1))]


(* ::Subsection:: *)
(*Coefficients in the "double-trace" construction*)


(* The coefficients in front of each term in 
	Joao's alternating derivative *)
PrimCoeffs[degL_,degR_,l_,k_]:=
	PrimCoeffs[degL,degR,l,k]=
		((-1)^k Gamma[2degL+l]Gamma[2degR+l]) / 
		(k!(l-k)!Gamma[2degL+k]Gamma[2degR+l-k]);


(* ::Section:: *)
(*End*)


End[]


EndPackage[]
