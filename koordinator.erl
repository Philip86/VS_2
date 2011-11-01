-module(koordinator).
-compile(export_all).

start() ->
	{ok, ConfigListe} = file:consult("koordinator.cfg"),
	{ok,NameServiceNode} = werkzeug:get_config_value(nameservicenode, ConfigListe),
	{ok,KoordinatorName} = werkzeug:get_config_value(koordinatorname, ConfigListe),
	{ok,GGTProzessNummer} = werkzeug:get_config_value(ggtprozessnummer, ConfigListe),
	{ok,TermZeit} = werkzeug:get_config_value(termzeit, ConfigListe),
	{ok,ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe),

		
	
	pong = net_adm:ping(NameServiceNode),
	timer:sleep(500),
	KAB = global:whereis_name(nameservice),
	io:format("Nameservice: ~p, NameserviceNode: ~p~n", [KAB, NameServiceNode]),
	timer:sleep(500),
	KAB ! {self(),{rebind,KoordinatorName,node()}},
	register(KoordinatorName, spawn(koordinator, init, [ArbeitsZeit, TermZeit, GGTProzessNummer, [], KAB])).

init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice) ->
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer},
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice);
		
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, [Clientname | GGTListe], Nameservice);
		letsgo ->
			createRing(GGTListe, Nameservice), 
			loop(GGTListe, Nameservice)	
	end.

createMis([], _) ->
	done;
createMis([Kopf| Rest], Nameservice)->
	io:format("Kopf: ~p \n",[Kopf]),
	Mi = calcRandomMi(),
	Nameservice  ! {self(),{lookup,Kopf}},
	receive 
		{Name,Node} -> 
			 GGTProzess = {Name, Node};
		not_found -> 
			GGTProzess = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	GGTProzess ! {setpm, Mi},
	createMis(Rest, Nameservice).
	

createRing(GGTListe, Nameservice)->
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	for_loop(0, ArrSize, Arr, Nameservice).
	
for_loop(N, Length, _, _) when N >= Length -> 
    io:format("Done!~n");

for_loop(N, Length, Arr, Nameservice) -> 
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
	Nameservice  ! {self(),{lookup, Current}},
	receive 
		{Name,Node} -> 
			 GGTProzess = {Name, Node};
		not_found -> 
			GGTProzess = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	GGTProzess ! {setneighbors, LeftN, RightN},
    for_loop(N+1, Length, Arr, Nameservice).

calcRandomMi()->
	Prims = [3, 5, 11, 13, 23, 37],
	WunschGGT = 13,
	calcRandomMiRec(Prims, WunschGGT).
calcRandomMiRec([],Produkt)->
	trunc(Produkt);
calcRandomMiRec([Kopf | Rest], Produkt) ->
	ProduktNew = Produkt * math:pow(Kopf, random:uniform(3)-1),
	calcRandomMiRec(Rest, ProduktNew).

startCalc(GGTListe, Nameservice)->
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	AnzStarter = trunc((ArrSize/100) * 15),
	if AnzStarter < 2 ->
		sendStartToClients(Arr, 2, [], ArrSize, Nameservice);
	true -> sendStartToClients(Arr, AnzStarter, [], ArrSize, Nameservice)
	end.

sendStartToClients(Arr, 0, UsedClients, ArrSize, Nameservice) -> 
	io:format("Koordinator hat das zufaellige Starten abgeschlossen \n");
sendStartToClients(Arr, N, UsedClients, ArrSize, Nameservice) ->
	ChoosenClient = random:uniform(ArrSize) -1,
	WasteBool = lists:member(ChoosenClient, UsedClients),
	if WasteBool ->
		sendStartToClients(Arr, N, UsedClients, ArrSize, Nameservice);
	true ->
		Client = array:get(ChoosenClient, Arr),
		RandomY =  calcRandomMi(),
		io:format("Koordinator schickt start an: ~p \n", [Client]),
		Nameservice  ! {self(),{lookup,Client}},
		receive 
			{Name,Node} -> 
				 GGTProzess = {Name, Node};
			not_found -> 
				GGTProzess = failed,
				io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
		end,
		GGTProzess ! {sendy, RandomY},
		sendStartToClients(Arr, N-1, [ChoosenClient| UsedClients], ArrSize, Nameservice)
	end.
		

loop(GGTListe, Nameservice) ->
	receive

		{briefmi, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert ¸ber sein neues Mi CMi um CZeit Uhr.			
			io:format("~p meldet neues Mi ~p um ~p. \n", [Clientname,CMi, CZeit]),
			loop(GGTListe, Nameservice);
		{briefterm, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert ¸ber ¸ber die Terminierung der Berechnung mit Ergebnis CMi um CZeit Uhr.
			io:format("~p meldet TERMINIERUNG !!! mit Mi ~p um ~p. \n", [Clientname,CMi, CZeit]),
			loop(GGTListe, Nameservice);
		reset -> %Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden kˆnnen.
			ka;
		kill -> %Der Koordinator wird beendet und sendet allen ggT-Prozessen das kill-Kommando.
			ka;
		startecalc ->
			io:format("Erzeuge Mis \n"),
			createMis(GGTListe, Nameservice),
			io:format("Mis erzeugt und beginne mit anstoﬂen \n"),
			startCalc(GGTListe, Nameservice),
			io:format("anstoﬂen finished \n"),
			loop(GGTListe, Nameservice)
	end.
