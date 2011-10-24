-module(starter).
-compile(export_all).

start() ->
	%{ok, ConfigListe} = file:consult("koordinator.cfg"),
	%{ok, ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe) * 1000,
	spawn(start, loop, {}).

loop() ->
	koor ! {getsteeringval, self()},
	receive
		{steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer} -> %die steuernden Werte für die ggT-Prozesse werden im Starter Prozess gesetzt; Arbeitszeit ist die simulierte Zeit zur Berechnung, TermZeit ist die Wartezeit, bis eine Wahl für eine Terminierung initiiert wird und GGTProzessnummer ist die Anzahl der zu startenden ggT-Prozesse.
			startGGTProzess(ArbeitsZeit, TermZeit, GGTProzessnummer)
	end.


startGGTProzess(_, _, 0) ->
	finished;
startGGTProzess(ArbeitsZeit, TermZeit, N) ->
	GGTName = 1700 + (N * 10) + 1,
	register(GGTName, spawn(ggt, start, {"namensDienst", cord, GGTName, ArbeitsZeit, TermZeit})),
	startGGTProzess(ArbeitsZeit, TermZeit, N - 1).