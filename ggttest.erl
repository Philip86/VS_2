-module(ggttest).
-compile(export_all).

start() ->
	Namensdienst = "Hans",
	KoordName = "Peter",
	ArbeitsZeit = 10000,
	TermZeit = 10000,
	register(p1, spawn(ggt, start, [Namensdienst, KoordName, g1, ArbeitsZeit, TermZeit])),
	register(p2, spawn(ggt, start, [Namensdienst, KoordName, g2, ArbeitsZeit, TermZeit])),
	register(p3, spawn(ggt, start, [Namensdienst, KoordName, g3, ArbeitsZeit, TermZeit])),
	register(p4, spawn(ggt, start, [Namensdienst, KoordName, g4, ArbeitsZeit, TermZeit])),
	koor ! {hello, p1},
	koor ! {hello, p2},
	koor ! {hello, p3},
	koor ! {hello, p4}.
	%p1 ! {setneighbors, p4, p2},
	%p2 ! {setneighbors, p1, p3},
	%p3 ! {setneighbors, p2, p4},
	%p4 ! {setneighbors, p3, p1},
	%p1 ! {setpm, 13*3},
	%p2 ! {setpm, 13*9},
	%p3 ! {setpm, 13*5},
	%p4 ! {setpm, 13*12},
	%p3 ! startSending,
	%loop().

	loop() ->
		receive
		needResult ->
			p1 ! {tellmi,self()},
			receive
			Mi -> P1Mi = Mi
			end,
			p2 ! {tellmi,self()},
			receive
			Mi -> P2Mi = Mi
			end,
			io:format("Mi von p1: ~p von p2: ~p", [P1Mi,P2Mi]),
			loop()
		end.
