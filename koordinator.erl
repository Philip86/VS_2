-module(koordinator).
-compile(export_all).

start() ->
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("koordinator ~p Startzeit: ~p mit PID ~p \r\n",[node(),werkzeug:timeMilliSecond(), self()])),
	{ok, ConfigListe} = file:consult("koordinator.cfg"),
	{ok,NameServiceNode} = werkzeug:get_config_value(nameservicenode, ConfigListe),
	{ok,KoordinatorName} = werkzeug:get_config_value(koordinatorname, ConfigListe),
	{ok,GGTProzessNummer} = werkzeug:get_config_value(ggtprozessnummer, ConfigListe),
	{ok,TermZeit} = werkzeug:get_config_value(termzeit, ConfigListe),
	{ok,ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe),

	werkzeug:logging("log/KoordinatorLog.log", stringFormat("koordinator.cfg gelesen \r\n",[])),
	pong = net_adm:ping(NameServiceNode),
	timer:sleep(500),
	KAB = global:whereis_name(nameservice),
	io:format("Nameservice: ~p, NameserviceNode: ~p~n", [KAB, NameServiceNode]),
	timer:sleep(500),
	register(KoordinatorName, spawn(koordinator, init, [ArbeitsZeit, TermZeit, GGTProzessNummer, [], KAB])),
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("lokal registriert... \r\n",[])),
	KAB ! {self(),{rebind,KoordinatorName,node()}},
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("beim Namensdienst registriert... \r\n",[])).


startInit(Nameservice) ->
	{ok, ConfigListe} = file:consult("koordinator.cfg"),
	{ok,GGTProzessNummer} = werkzeug:get_config_value(ggtprozessnummer, ConfigListe),
	{ok,TermZeit} = werkzeug:get_config_value(termzeit, ConfigListe),
	{ok,ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe),	
	
	init(ArbeitsZeit, TermZeit, GGTProzessNummer, [], Nameservice).
	
init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice) ->
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("getsteeringval: ~p \r\n",[Starter])),
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer},
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice);
		
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("hello: ~p \r\n",[Clientname])),
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, [Clientname | GGTListe], Nameservice);
		letsgo ->
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Anmeldefrist abgelaufen, beginne mit Erzeugung des Ringes \r\n",[])),
			createRing(GGTListe, Nameservice), 
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Alle Prozesse wurden ueber Nachbarsn informiert. \r\n",[])),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Ring erzeugt, gehe in Bereitphase \r\n",[])),
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
			Node = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("ggt-Prozess ~p ~p initiales Mi: ~p gesendet \r\n",[Kopf, Node, Mi])),
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
			Node = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("ggt- Prozess ~p ~p ueber linken Nachbarn: ~p und rechten Nachbarn ~p informiert. \r\n",[Current, Node, LeftN, RightN])),
	GGTProzess ! {setneighbors, LeftN, RightN},
    for_loop(N+1, Length, Arr, Nameservice).

getWunschGGT() ->
	13.

calcRandomMi()->
	Prims = [3, 5, 11, 13, 23, 37],
	WunschGGT = getWunschGGT(),
	calcRandomMiRec(Prims, WunschGGT).
calcRandomMiRec([],Produkt)->
	trunc(Produkt);
calcRandomMiRec([Kopf | Rest], Produkt) ->
	ProduktNew = Produkt * math:pow(Kopf, random:uniform(3)-1),
	calcRandomMiRec(Rest, ProduktNew).


killGGTs([], _) ->
	done;
killGGTs([Kopf| Rest], Nameservice) ->
	Nameservice  ! {self(),{lookup, Kopf}},
	receive 
		{Name,Node} -> 
			 GGTProzess = {Name, Node};
		not_found -> 
			GGTProzess = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	GGTProzess ! kill,
	killGGTs(Rest, Nameservice).
	
% Zur Berechnung und Versendung des zufaelligen Y an 15% der GGTS zum starten!!!
startCalc(GGTListe, Nameservice)->
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	AnzStarter = trunc((ArrSize/100) * 15),
	if AnzStarter < 2 ->
		sendStartToClients(Arr, 2, [], ArrSize, Nameservice);
	true -> 
		sendStartToClients(Arr, AnzStarter, [], ArrSize, Nameservice)
	end.

sendStartToClients(_, 0, _, _, _) -> 
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("Verwendung startender Y Werte, abgeschlossen! \r\n",[])),
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
				Node = failed,
				io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
		end,
		werkzeug:logging("log/KoordinatorLog.log", stringFormat("ggt Prozess ~p ~p erhaelt startendes Y: ~p \r\n",[Client, Node, RandomY])),
		GGTProzess ! {sendy, RandomY},
		sendStartToClients(Arr, N-1, [ChoosenClient| UsedClients], ArrSize, Nameservice)
	end.
		

loop(GGTListe, Nameservice) ->
	receive

		{briefmi, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert �ber sein neues Mi CMi um CZeit Uhr.			
			%io:format("~p meldet neues Mi ~p um ~p. \n", [Clientname,CMi, CZeit]),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("~p meldet neues Mi ~p um ~p. \n", [Clientname,CMi, CZeit])),
			loop(GGTListe, Nameservice);
		{briefterm, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert �ber �ber die Terminierung der Berechnung mit Ergebnis CMi um CZeit Uhr.
			%io:format("~p meldet TERMINIERUNG !!! mit Mi ~p um ~p. \n", [Clientname,CMi, CZeit]),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("~p meldet TERMINIERUNG !!! mit Mi ~p um ~p. \n", [Clientname,CMi, CZeit])),
			loop(GGTListe, Nameservice);
		reset -> %Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden k�nnen.
			killGGTs(GGTListe, Nameservice),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Allen GGT Prozessen ein kill gesendet \r\n Starte initialphase \r\n",[])),
			startInit(Nameservice);
		kill -> %Der Koordinator wird beendet und sendet allen ggT-Prozessen das kill-Kommando.
			killGGTs(GGTListe, Nameservice),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Allen GGT Prozessen ein kill gesendet \r\n",[])),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Downtime: ~p von Koordinator chef \r\n",[werkzeug:timeMilliSecond()]));
		startecalc ->
			io:format("Erzeuge Mis \n"),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Wunsch GGT = ~p \r\n",[getWunschGGT()])),
			createMis(GGTListe, Nameservice),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Beginne mit Berechnung fuer zufaelligs Y zum starten: \r\n",[])),
			startCalc(GGTListe, Nameservice),
			io:format("ansto�en finished \n"),
			loop(GGTListe, Nameservice)
	end.

stringFormat(String, Args) ->
	lists:flatten(io_lib:format(String, Args)).
%logFileName(Name) ->
%	lists:flatten(io_lib:format(
