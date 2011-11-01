-module(ggt).
-compile(export_all).

start(NamensdienstNode, KoordName, MeinName, ArbeitsZeit, TermZeit) -> 
	register(MeinName, self()),	
	pong = net_adm:ping(NamensdienstNode),
	Nameservice2 = global:whereis_name(nameservice),
	io:format("ggt oka: ~p \n"),
	Nameservice2 ! {self(),{rebind,MeinName,node()}},
	io:format("ggtasdlksajdlkj\n"),
	receive
		ok -> true
	end,
	io:format("g445\n"),
	Nameservice2  ! {self(),{lookup,KoordName}},
	receive 
		{Name,Node} -> 
			{Name, Node} ! {hello, MeinName};
		not_found -> 
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	receive	
		{setneighbors, LeftN, RightN} -> true
			%loop(Mi, LeftN, RightN, Terminate)
	end,
	receive
		{setpm, MiNeu} ->
			loop(MiNeu, LeftN, RightN, NamensdienstNode, KoordName, MeinName, ArbeitsZeit * 1000, infinity, TermZeit * 1000)
	end.

loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeitDauer, TermZeit) ->
		Timestamp1 = now(),
	receive
		%{setneighbors, LeftN, RightN} -> 
		%	loop(Mi, LeftN, RightN);
		{setpm, MiNeu} ->
			loop(MiNeu, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeit, TermZeit);
		{sendy, Y} ->
			NewMi = calcGgt(Mi, Y, NeighborL, NeighborR, KoordName, MeinName, ArbeitsZeit),
			io:format("Neuer MI von: ~p  ist = ~p \n", [MeinName, NewMi]),
			loop(NewMi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeit, TermZeit);
		{abstimmung,Initiator} -> 
			Timestamp2 = now(),
			if Initiator == self() ->
				io:format("~p bekommt Anfrageabstimmung von ~p, also von sich selbst \n", [MeinName, Initiator]),
				NewTermZeit = infinity,
				CZeit = werkzeug:timeMilliSecond(),
				KoordName ! {briefterm, {MeinName, Mi, CZeit}};
				true ->
					TimeDiff = timer:now_diff(Timestamp2, Timestamp1) / 1000,
					io:format("Prozess: ~p Differenz: ~p, TermzeitDauer: ~p \n", [MeinName,TimeDiff, TermZeitDauer]),
						%EVTL NOCH UMRECHNEN IN SEK
					if (TimeDiff >= (TermZeit * 2 / 3)) or (TermZeitDauer == infinity) ->
						io:format("~p bekommt Anfrageabstimmung von ~p und leitet an Nachbarn weiter \n", [MeinName, Initiator]),
						io:format("Dabei ist TimeDiff = ~p und 2/3 der Termzeit = ~p \n", [TimeDiff, (TermZeit*2/3)]),
						NeighborR ! {abstimmung, Initiator},
						NewTermZeit = infinity;
					true ->
						NewTermZeit = trunc(TermZeit - TimeDiff),
						io:format("~p bekommt Anfrageabstimmung von ~p und ignoriert diese Anfrage. Neue Termzeit dabei = ~p \n", [MeinName, Initiator, NewTermZeit])
					end
			end,
			io:format("\n\n NewtermZeit = ~p \n\n", [NewTermZeit]),
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,NewTermZeit, TermZeit);	
		{tellmi,From} -> 
			Timestamp2 = now(),
			From ! Mi,
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeitDauer, TermZeit);
		kill -> death
	after TermZeitDauer -> 
			NeighborR ! {abstimmung, self()},
			io:format("Prozess ~p startet Terminierungsabstimmung \n", [MeinName]),
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,infinity, TermZeit)
	end.
	

calcGgt(Mi, Y,LeftN, RightN, KoordName, MeinName, ArbeitsZeit) ->
	io:format("CalcGGT Fun von: ~p  mit Mi = ~p   und Y = ~p \n", [MeinName,Mi,Y]),
	if Y < Mi -> 
		NewMi = ((Mi - 1) rem Y) + 1,
		timer:sleep(ArbeitsZeit),
		CZeit = werkzeug:timeMilliSecond(),
		KoordName ! {briefmi,{MeinName, NewMi, CZeit}},
		LeftN ! {sendy, NewMi},
		RightN ! {sendy, NewMi},
		NewMi;
		true -> Mi
	end. 
%{Eine Nachricht <y> ist eingetroffen}
 % if y < Mi 
  %  then Mi := mod(Mi-1,y)+1;
   %      send #Mi to all neighbours;
 % fi 
