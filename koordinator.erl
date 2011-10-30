-module(koordinator).
-compile(export_all).

start() ->
	%{ok, ConfigListe} = file:consult("koordinator.cfg"),
	%{ok, ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe) * 1000,
	register(koor, spawn(koordinator, init, [3000, 3000, 20, []])).

init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe) ->
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer},
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe);
		
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, [Clientname | GGTListe]);
		letsgo ->
			createRingAndMis(GGTListe), 
			startCalc(GGTListe),
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
	Mi = calcRandomMi(),
	Current ! {setpm, Mi},
    for_loop(N+1, Length, Arr).

calcRandomMi()->
	Prims = [3, 5, 11, 13, 23, 37],
	calcRandomMiRec(Prims, 0).
calcRandomMiRec([],Summe)->
	trunc(Summe);
calcRandomMiRec([Kopf | Rest], Summe) ->
	SummeNew = Summe + math:pow(Kopf, random:uniform(3)-1),
	calcRandomMiRec(Rest, SummeNew).

startCalc(GGTListe)->
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	AnzStarter = trunc((ArrSize/100) * 15),
	if AnzStarter < 2 ->
		sendStartToClients(Arr, 2, [], ArrSize);
	true -> sendStartToClients(Arr, AnzStarter, [], ArrSize)
	end.

sendStartToClients(Arr, 0, UsedClients, ArrSize) -> 
	io:format("Koordinator hat das zufaellige Starten abgeschlossen \n");
sendStartToClients(Arr, N, UsedClients, ArrSize) ->
	ChoosenClient = random:uniform(ArrSize) -1,
	WasteBool = lists:member(ChoosenClient, UsedClients),
	if WasteBool ->
		sendStartToClients(Arr, N, UsedClients, ArrSize);
	true ->
		Client = array:get(ChoosenClient, Arr),
		RandomY =  calcRandomMi(),
		io:format("Koordinator schickt start an: ~p \n", [Client]),
		Client ! {sendy, RandomY},
		sendStartToClients(Arr, N-1, [ChoosenClient| UsedClients], ArrSize)
	end.
		

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
