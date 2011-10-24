-module(ggt).
-compile(export_all).

start(Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit) -> 
	%KoordName ! hello,
	%Namensdienst ! {rebind self()}

	receive	
		{setneighbors, LeftN, RightN} -> true
			%loop(Mi, LeftN, RightN, Terminate)
	end,
	receive
	{setpm, MiNeu} ->
		loop(MiNeu, LeftN, RightN, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit)
	end.

loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit) ->
	receive
		%{setneighbors, LeftN, RightN} -> 
		%	loop(Mi, LeftN, RightN);
		{setpm, MiNeu} ->
			loop(MiNeu, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit);
		{sendy, Y} ->
			NewMi = calcGgt(Mi, Y, NeighborL, NeighborR, KoordName, MeinName),
			loop(NewMi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit);
		{abstimmung,Initiator} -> 
			%KOMMT NOCH!!!!
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit);
		{tellmi,From} -> 
			From ! Mi,
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit, TermZeit);
		kill -> death
	end.

calcGgt(Mi, Y,LeftN, RightN, KoordName, MeinName) ->
	if Y < Mi -> 
		NewMi = ((Mi - 1) rem Y) + 1,
		%MUSS NOCH !!!
		%KoordName ! {briefmi,{MeinName,NewMi,CZeit}},
		LeftN ! {setpm, NewMi},
		RightN ! {setpm, NewMi},
		NewMi;
		true -> Mi
	end. 
%{Eine Nachricht <y> ist eingetroffen}
 % if y < Mi 
  %  then Mi := mod(Mi-1,y)+1;
   %      send #Mi to all neighbours;
 % fi 
