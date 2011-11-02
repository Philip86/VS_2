-module(starter).
-compile(export_all).

start(Id) ->
	MsgText = lists:concat([logPrefix(Id), stringFormat("Startzeit: ~p mit PID ~p", [werkzeug:timeMilliSecond(), self()])]),
	werkzeug:logging(logFileName(Id), lists:concat([MsgText, "\r\n"])),

	{ok, ConfigListe} = file:consult("ggt.cfg"),
	%{nameservicenode, 'ns@lab33.cpt.haw-hamburg.de'}.
	{ok,NameServiceNode} = werkzeug:get_config_value(nameservicenode, ConfigListe),
	{ok,KoordinatorName} = werkzeug:get_config_value(koordinatorname, ConfigListe),
	{ok,Teamnummer} = werkzeug:get_config_value(teamnummer, ConfigListe),
	{ok,PraktikumsGruppe} = werkzeug:get_config_value(praktikumsgruppe, ConfigListe),
	
	werkzeug:logging(logFileName(Id), lists:concat(["ggt.cfg gelesen...", "\r\n"])),
	
	pong = net_adm:ping(NameServiceNode),
	Nameservice = global:whereis_name(nameservice),
	werkzeug:logging(logFileName(Id), lists:concat(["Namenservice gebunden...", "\r\n"])),
	
	%io:format("Namenservice: ~p\n", [Nameservice]),
	Nameservice ! {self() ,{lookup,KoordinatorName}},
	receive 
		{Name,Node} ->
			werkzeug:logging(logFileName(Id), lists:concat([stringFormat("Koordinator chef (~p) gebunden.", [KoordinatorName]), "\r\n"])),
			io:format("Name: ~p, Node: ~p\n", [Name, Node]),
			{Name, Node} ! {getsteeringval, self()},
			receive
				{steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer} -> %die steuernden Werte für die ggT-Prozesse werden im Starter Prozess gesetzt; Arbeitszeit ist die simulierte Zeit zur Berechnung, 				TermZeit ist die Wartezeit, bis eine Wahl für eine Terminierung initiiert wird und GGTProzessnummer ist die Anzahl der zu startenden ggT-Prozesse.
					MsgGetSteeringVal = stringFormat("getsteeringval: ~p Arbeitszeit ggT;~p Wartezeit ggT;~p Anzahl GGT Prozesse.", [ArbeitsZeit, TermZeit, GGTProzessnummer]),
					werkzeug:logging(logFileName(Id), lists:concat([MsgGetSteeringVal, "\r\n"])),
					startGGTProzess(NameServiceNode, KoordinatorName,  Teamnummer, PraktikumsGruppe,Id, ArbeitsZeit, TermZeit, GGTProzessnummer)
			end;
		not_found -> 
			io:format("Starter konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end.

startGGTProzess(_, _, _, _, _, _, _, 0) ->
	finished;
startGGTProzess(NameServiceNode, KoordinatorName, Teamnummer, PraktikumsGruppe, StarterId, ArbeitsZeit, TermZeit, N) ->
	GGTName = list_to_atom(integer_to_list((PraktikumsGruppe*1000) + (Teamnummer * 100) + (N * 10) + StarterId)),
	spawn(ggt, start, [NameServiceNode, KoordinatorName, GGTName, ArbeitsZeit, TermZeit]),
	startGGTProzess(NameServiceNode,KoordinatorName, Teamnummer, PraktikumsGruppe, StarterId, ArbeitsZeit, TermZeit, N - 1).


logFileName(StarterId) ->
		lists:flatten(io_lib:format("log/ggtStarter_~p~p.log", [StarterId, node()])).

logPrefix(StarterId) ->
	lists:flatten(io_lib:format("Starter_~p-~p-07: ", [StarterId, node()])).

stringFormat(String, Args) ->
	lists:flatten(io_lib:format(String, Args)).