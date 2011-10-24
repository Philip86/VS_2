-module(starter).
-export(export_all).

start() ->
	%{ok, ConfigListe} = file:consult("koordinator.cfg"),
	%{ok, ArbeitsZeit} = werkzeug:get_config_value(arbeitszeit, ConfigListe) * 1000,
	register(koor, spawn(koordinator, loop, {3000, 3000, 3})).

loop(ArbeitsZeit, TermZeit, GGTProzessnummer) ->
	receive
		{getsteeringval, Starter} -> %Die Anfrage nach den steuernden Werten durch den Starter Prozess.
			Starter ! {steeringval, ArbeitsZeit, TermZeit, GGTProzessnummer};
		{hello, Clientname} -> %Ein ggT-Prozess meldet sich beim Koordinator mit Namen Clientname an (Name ist der lokal registrierte Name!).		
			;
		{briefmi, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert über sein neues Mi CMi um CZeit Uhr.
			;
		{briefterm, {Clientname, CMi, CZeit}} -> %Ein ggT-Prozess mit Namen Clientname informiert über über die Terminierung der Berechnung mit Ergebnis CMi um CZeit Uhr.
			;
		reset -> %Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden können.
			;
		kill -> %Der Koordinator wird beendet und sendet allen ggT-Prozessen das kill-Kommando.
			
	end.