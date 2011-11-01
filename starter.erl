-module(starter).
-compile(export_all).

start(Id) ->
	{ok, ConfigListe} = file:consult("ggt.cfg"),
	%{nameservicenode, 'ns@lab33.cpt.haw-hamburg.de'}.
	{ok,NameServiceNode} = werkzeug:get_config_value(nameservicenode, ConfigListe),
	{ok,KoordinatorName} = werkzeug:get_config_value(koordinatorname, ConfigListe),
	{ok,Teamnummer} = werkzeug:get_config_value(teamnummer, ConfigListe),
	{ok,PraktikumsGruppe} = werkzeug:get_config_value(praktikumsgruppe, ConfigListe),
	
	pong = net_adm:ping(NameServiceNode),
	Nameservice = global:whereis_name(nameservice),
	%io:format("namens: ~p\n", [Nameservice]),
	Nameservice ! {self() ,{lookup,KoordinatorName}},
	%io:format("3asda\n	", []),
	receive 
		{Name,Node} ->
			io:format("Name: ~p, Node: ~p\n", [Name, Node]),
			{Name, Node} ! {getsteeringval, self()},
			receive
				{steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer} -> %die steuernden Werte für die ggT-Prozesse werden im Starter Prozess gesetzt; Arbeitszeit ist die simulierte Zeit zur Berechnung, 				TermZeit ist die Wartezeit, bis eine Wahl für eine Terminierung initiiert wird und GGTProzessnummer ist die Anzahl der zu startenden ggT-Prozesse.
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
