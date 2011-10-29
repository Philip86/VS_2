-module(koordinator).
-compile(export_all).

start() ->
	%{ok, ConfigListe} = file:consult("koordinator.cfg"),
	%{ok, ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe) * 1000,
	register(koor, spawn(koordinator, init, [3000, 3000, 3, []])).

init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe) ->
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer},
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe);
		
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, [Clientname | GGTListe]);
		letsgo ->
			createRingAndMis(GGTListe), 
			loop(ArbeitsZeit, TermZeit, GGTProzessnummer)	
	end.

createRingAndMis(GGTListe)->
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	for_loop(0, ArrSize, Arr).
	
for_loop(N, Length, _) when N >= Length -> 
    io:format("Done!~n");
for_loop(N, Length, Arr) -> 
	Current = array:get(N, Arr),
	if N == 0 ->
		LeftN = array:get(Length -1, Arr),
		RightN = array:get(N +1, Arr);
	  N == Length -1 ->
		LeftN = array:get(N -1, Arr),
		RightN = array:get(0, Arr);
	 true ->
		LeftN = array:get(N -1, Arr),
		RightN = array:get(N +1, Arr)
	end,
	io:format("Links: ~p ERHIER!!! ~p  Rechts: ~p \n",[LeftN, Current, RightN]),
	Current ! {setneighbors, LeftN, RightN},
	Current ! {setpm, (N+1)*13},
    for_loop(N+1, Length, Arr).


loop(ArbeitsZeit, TermZeit, GGTProzessnummer) ->
	receive

		{briefmi, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert über sein neues Mi CMi um CZeit Uhr.
			ka;
		{briefterm, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert über über die Terminierung der Berechnung mit Ergebnis CMi um CZeit Uhr.
			ka;
		reset -> %Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden können.
			ka;
		kill -> %Der Koordinator wird beendet und sendet allen ggT-Prozessen das kill-Kommando.
			ka
	end.
