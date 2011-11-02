-module(koordinator).
-compile(export_all).

start() ->
	%Ließt Werte aus dem Config
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("koordinator ~p Startzeit: ~p mit PID ~p \r\n",[node(),werkzeug:timeMilliSecond(), self()])),
	{ok, ConfigListe} = file:consult("koordinator.cfg"),
	{ok,NameServiceNode} = werkzeug:get_config_value(nameservicenode, ConfigListe),
	{ok,KoordinatorName} = werkzeug:get_config_value(koordinatorname, ConfigListe),
	{ok,GGTProzessNummer} = werkzeug:get_config_value(ggtprozessnummer, ConfigListe),
	{ok,TermZeit} = werkzeug:get_config_value(termzeit, ConfigListe),
	{ok,ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe),

	werkzeug:logging("log/KoordinatorLog.log", stringFormat("koordinator.cfg gelesen \r\n",[])),
	%Pingt den Namensdienst an.
	pong = net_adm:ping(NameServiceNode),
	timer:sleep(500),
	KAB = global:whereis_name(nameservice),
	io:format("Nameservice: ~p, NameserviceNode: ~p~n", [KAB, NameServiceNode]),
	timer:sleep(500),
	register(KoordinatorName, spawn(koordinator, init, [ArbeitsZeit, TermZeit, GGTProzessNummer, [], KAB])),
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("lokal registriert... \r\n",[])),
	KAB ! {self(),{rebind,KoordinatorName,node()}},
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("beim Namensdienst registriert... \r\n",[])).

%Funktion welche erneut in die Initalisierungsphase geht. Nur brauchbar bei resetfunktion!!!
startInit(Nameservice) ->
	{ok, ConfigListe} = file:consult("koordinator.cfg"),
	{ok,GGTProzessNummer} = werkzeug:get_config_value(ggtprozessnummer, ConfigListe),
	{ok,TermZeit} = werkzeug:get_config_value(termzeit, ConfigListe),
	{ok,ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe),	
	
	init(ArbeitsZeit, TermZeit, GGTProzessNummer, [], Nameservice).
%Initphase	
init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice) ->
	%Wartet auf Anfragen vom Starter, oder Anmeldungen von GGTs
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("getsteeringval: ~p \r\n",[Starter])),
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer},
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, GGTListe, Nameservice);
		
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("hello: ~p \r\n",[Clientname])),
			init(ArbeitsZeit, TermZeit, GGTProzessnummer, [Clientname | GGTListe], Nameservice);
		%Manueller Aufruf um in die bereitfunktion (loop) zu wechseln
		letsgo ->
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Anmeldefrist abgelaufen, beginne mit Erzeugung des Ringes \r\n",[])),
			createRing(GGTListe, Nameservice), 
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Alle Prozesse wurden ueber Nachbarsn informiert. \r\n",[])),
			werkzeug:logging("log/KoordinatorLog.log", stringFormat("Ring erzeugt, gehe in Bereitphase \r\n",[])),
			loop(GGTListe, Nameservice)	
	end.

%Rekursive Funktion zur Versendung der Mis an die GGT Prozesse
%Wenn Liste leer, Abbruch 
createMis([], _) ->
	done;
%Liste besteht aus GGT Prozessen, Kopf = der Prozess, an den Mi jeweils gesendet werden soll
createMis([Kopf| Rest], Nameservice)->
	%io:format("Kopf: ~p \n",[Kopf]),
	Mi = calcRandomMi(),
	%Anfrage an den Namensdienst um PID und Node von GGTProzess zu erhalten
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
	%Mi wird an den GGT Prozess gesendet!!
	GGTProzess ! {setpm, Mi},
	%Rekursiver Aufruf ohne den Prozess an den bereits versendet wurde
	createMis(Rest, Nameservice).
	
%Funktion für die Ringerzeugung
createRing(GGTListe, Nameservice)->
	%Umwandlung der GGT Liste in ein Array, um auf vor und Nachfolger zugreifen zu können
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	%Aufruf einer forschleifen funktion
	for_loop(0, ArrSize, Arr, Nameservice).

%Abbruch wenn N größer als die Arraylänge ist.	
for_loop(N, Length, _, _) when N >= Length -> 
    io:format("Done!~n");


for_loop(N, Length, Arr, Nameservice) -> 
	%Aktuelles Element wird bestimmt.
	Current = array:get(N, Arr),
	%Falls N das erste Element der Liste ist, so ist sein linker Nachbar das letzte Element
	
	if N == 0 ->
		LeftN = array:get(Length -1, Arr),
		RightN = array:get(N +1, Arr);
	%Falls Element das letzte der Liste ist, so ist sein rechter Nachbar das erste Element
	  N == Length -1 ->
		LeftN = array:get(N -1, Arr),
		RightN = array:get(0, Arr);
	%Ansonsten ist der linke Nachbar der vorgänger und der rechte der Nachfolger der Liste
	 true ->
		LeftN = array:get(N -1, Arr),
		RightN = array:get(N +1, Arr)
	end,
	io:format("Links: ~p ERHIER!!! ~p  Rechts: ~p \n",[LeftN, Current, RightN]),
	Nameservice  ! {self(),{lookup, Current}},
	%Anfrage an den Namensdienst um PID und Node von GGTProzess zu erhalten
	receive 
		{Name,Node} -> 
			 GGTProzess = {Name, Node};
		not_found -> 
			GGTProzess = failed,
			Node = failed,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("ggt- Prozess ~p ~p ueber linken Nachbarn: ~p und rechten Nachbarn ~p informiert. \r\n",[Current, Node, LeftN, RightN])),
	%Versendung der Nachbarn an den GGTProzess
	GGTProzess ! {setneighbors, LeftN, RightN},
    for_loop(N+1, Length, Arr, Nameservice).

%Einfache Funktion für den WunschGGT
getWunschGGT() ->
	13.

%Berechnet den Zufalls Mi.
calcRandomMi()->
	Prims = [3, 5, 11, 13, 23, 37],
	WunschGGT = getWunschGGT(),
	%Aufruf rekursiver Funktion für die Berechnung
	calcRandomMiRec(Prims, WunschGGT).
	%Abbruch wenn PrimzahlListe leer ist
calcRandomMiRec([],Produkt)->
	trunc(Produkt);

calcRandomMiRec([Kopf | Rest], Produkt) ->
	%Zu dem Produk wird das aktuelle Primzahl Element aus der Liste mit einer zufaelligen Potenz multipliziert
	ProduktNew = Produkt * math:pow(Kopf, random:uniform(3)-1),
	calcRandomMiRec(Rest, ProduktNew).


killGGTs([], _) ->
	done;
%Versendet an jeden GGtProzess die Nachricht Kill
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
	%Umwandlung der GGtListe in ein Array um direkte Indexierungsmöglichkeit zu haben
	Arr = array:from_list(GGTListe),
	ArrSize = array:size(Arr),
	%Anzahl der Starter wird auf 15% festgelegt danach trunciert um ganzzahl zu erhalten
	AnzStarter = trunc((ArrSize/100) * 15),
	%Wenn die anzahl der Starter kleiner als 2 ist wird der Wert auf 2 gelegt
	if AnzStarter < 2 ->
		sendStartToClients(Arr, 2, [], ArrSize, Nameservice);
	true -> 
		sendStartToClients(Arr, AnzStarter, [], ArrSize, Nameservice)
	end.

sendStartToClients(_, 0, _, _, _) -> 
	werkzeug:logging("log/KoordinatorLog.log", stringFormat("Verwendung startender Y Werte, abgeschlossen! \r\n",[])),
	io:format("Koordinator hat das zufaellige Starten abgeschlossen \n");
	%Funktion um an die Starter zusenden, erhält ein N für die Anzahl der Starter und eine Liste mit bereits verwendeten indizes um nicht an gleichen Client doppelt zu senden.
sendStartToClients(Arr, N, UsedClients, ArrSize, Nameservice) ->
	%Zufaellige wahl eines Index aus der Groeße des Arrays
	ChoosenClient = random:uniform(ArrSize) -1,
	WasteBool = lists:member(ChoosenClient, UsedClients),
	%Wenn gewaehlter Clientindex bereits benutzt wurde, starte rekursiven Aufruf, ohne runterzaehlen.
	if WasteBool ->
		sendStartToClients(Arr, N, UsedClients, ArrSize, Nameservice);
	true ->
		%Hole Element aus Array an stelle des gewaehlten Index
		Client = array:get(ChoosenClient, Arr),
		%Berechne RandomY genau wie RandomMi
		RandomY =  calcRandomMi(),
		io:format("Koordinator schickt start an: ~p \n", [Client]),
		Nameservice  ! {self(),{lookup,Client}},
		%Hole von Namensdienst PID und Node vom gewaehlten Prozess
		receive 
			{Name,Node} -> 
				 GGTProzess = {Name, Node};
			not_found -> 
				GGTProzess = failed,
				Node = failed,
				io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
		end,
		werkzeug:logging("log/KoordinatorLog.log", stringFormat("ggt Prozess ~p ~p erhaelt startendes Y: ~p \r\n",[Client, Node, RandomY])),
		%Sendet RandomY Wert an den Prozess
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
