-module(ggt).
-compile(export_all).

start(Mi) -> 
	receive	
		{setneighbors, LeftN, RightN} -> 
			loop(Mi, LeftN, RightN)
	end.

loop(Mi, NeighborL, NeighborR) ->
	receive
		%{setneighbors, LeftN, RightN} -> 
		%	loop(Mi, LeftN, RightN);
		{setpm, MiNeu} ->
			loop(MiNeu, NeighborL, NeighborR);
		{sendy, Y} ->
			NewMi = calcGgt(Mi, Y, NeighborL, NeighborR),
			loop(NewMi, NeighborL, NeighborR);
		{abstimmung,Initiator} -> 
			%KOMMT NOCH!!!!
			loop(Mi, NeighborL, NeighborR);
		{tellmi,From} -> 
			From ! Mi,
			loop(Mi, NeighborL, NeighborR);
		kill -> death
	end.

calcGgt(Mi, Y,LeftN, RightN) ->
	if Y < Mi -> 
		NewMi = ((Mi - 1) rem Y) + 1,
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
