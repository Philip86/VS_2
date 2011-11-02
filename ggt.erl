-module(ggt).
-compile(export_all).

start(NamensdienstNode, KoordName, MeinName, ArbeitsZeit, TermZeit) ->
	
	MsgText = stringFormat("~p Startzeit: ~p mit PID ~p auf ~p", [MeinName, werkzeug:timeMilliSecond(), self(), node()]),
	werkzeug:logging(logFileName(MeinName), lists:concat([MsgText, "\r\n"])),
 
	%Registriert sich lokal
	register(MeinName, self()),
	
	%Bindet/Registriert sich mit dem Namensservice
	pong = net_adm:ping(NamensdienstNode),
	Nameservice2 = global:whereis_name(nameservice),
	Nameservice2 ! {self(),{rebind,MeinName,node()}},
	receive
		ok -> true
	end,
	werkzeug:logging(logFileName(MeinName), "beim Namensdienst und auf Node lokal registriert\r\n"),
	
	%Meldet sich beim Koordinator �ber Schnittstelle hello an
	Nameservice2  ! {self(),{lookup,KoordName}},
	receive 
		{Name,Node} -> 
			werkzeug:logging(logFileName(MeinName), "beim Koordinator gemeldet.\r\n"),
			Koordi = {Name, Node},
			Koordi ! {hello, MeinName};
		not_found -> 
			Koordi = traurig,
			io:format("GGT konnte Koordinator nicht finden und beendet sich ganz traurig :(\n")
	end,

	%Setzt linken und rechten Nachbar
	receive	
		{setneighbors, LeftN, RightN} -> 
			Nameservice2  ! {self(),{lookup,LeftN}},
			receive 
				{Name1,Node1} -> 
					werkzeug:logging(logFileName(MeinName), stringFormat("Linker Nachbar ~p gebunden.\r\n", [LeftN])),
					LeftName2 = {Name1, Node1};
				not_found -> 
					LeftName2 = fehler,
					io:format("GGT ~p konnte linken Nachbarn nicht finden und beendet sich ganz traurig :(\n", [MeinName])
			end,
			Nameservice2  ! {self(),{lookup,RightN}},
			receive 
				{Name2,Node2} -> 
					werkzeug:logging(logFileName(MeinName), stringFormat("Rechter Nachbar ~p gebunden.\r\n", [RightN])),
					RightName2 = {Name2, Node2};
				not_found -> 
					RightName2 = fehler,
					io:format("GGT ~p konnte rechten Nachbarn nicht finden und beendet sich ganz traurig :(\n", [MeinName])
			end
	end,
	
	%Startet Bereitphase
	Timestamp1 = now(),
	loop(-1, LeftName2, RightName2, Nameservice2, Koordi, MeinName, ArbeitsZeit * 1000, infinity, TermZeit * 1000, Timestamp1).



loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeitDauer, TermZeit, Timestamp) ->
	%Timestamp1 = now(),
	receive
		%Initilisiert Mi
		{setpm, MiNeu} ->
			Timestamp1 = now(),
			%io:format("Prozess ~p hat neues Mi erhalten! \n",[MeinName]),
			werkzeug:logging(logFileName(MeinName), stringFormat("setpm: ~p.\r\n", [MiNeu])),
			loop(MiNeu, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeit, TermZeit, Timestamp1);
		
		%Berechnung?
		{sendy, Y} ->
			Timestamp1 = now(),
			NewMi = calcGgt(Mi, Y, NeighborL, NeighborR, KoordName, MeinName, ArbeitsZeit),
			%io:format("Neuer MI von: ~p  ist = ~p \n", [MeinName, NewMi]),
			loop(NewMi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,TermZeit, TermZeit, Timestamp1);

		%Abstimmungsanfrage angekommen
		{abstimmung,Initiator} -> 
			Timestamp2 = now(),
			if 
				Initiator == MeinName ->
					%Anfrageabstimmung bei sich selbst angekommen
					%io:format("~p bekommt Anfrageabstimmung von ~p, also von sich selbst \n", [MeinName, Initiator]),
					NewTermZeit = infinity,
					CZeit = werkzeug:timeMilliSecond(),
					%io:format("Der Koordname = ~p\n", [KoordName]),
					werkzeug:logging(logFileName(MeinName), stringFormat("~p: stimme ab (~p): Koordinator Terminierung gemeldet mit ~p. ~p\r\n", [MeinName, Initiator, Mi, werkzeug:timeMilliSecond()])),
					KoordName ! {briefterm, {MeinName, Mi, CZeit}};
				true ->
					TimeDiff = timer:now_diff(Timestamp2, Timestamp) / 1000,
					%io:format("Prozess: ~p Differenz: ~p, TermzeitDauer: ~p \n", [MeinName,TimeDiff, TermZeitDauer]),
					if 
						(TimeDiff >= (TermZeit * 2 / 3)) or (TermZeitDauer == infinity) ->
							%Anfrage wird weitergeleitet
							%io:format("~p bekommt Anfrageabstimmung von ~p und leitet an Nachbarn weiter \n", [MeinName, Initiator]),
							%io:format("Dabei ist TimeDiff = ~p und 2/3 der Termzeit = ~p \n", [TimeDiff, (TermZeit*2/3)]),
							werkzeug:logging(logFileName(MeinName), stringFormat("~p: stimme ab (~p): mit >JA< gestimmt und weitergeleitet. ~p\r\n", [MeinName, Initiator, werkzeug:timeMilliSecond()])),
							NeighborR ! {abstimmung, Initiator},
							NewTermZeit = infinity;
						true ->
							%Anfrage wird ignoriert
							werkzeug:logging(logFileName(MeinName), stringFormat("~p: stimme ab (~p): mit >NEIN< gestimmt und ignoriert.\r\n", [MeinName, Initiator])),
							%io:format("~p bekommt Anfrageabstimmung von ~p und ignoriert diese Anfrage. Neue Termzeit dabei = ~p \n", [MeinName, Initiator, NewTermZeit]),
							NewTermZeit = trunc(TermZeit - TimeDiff)
					end
			end,
			%io:format("\n\n NewtermZeit = ~p \n\n", [NewTermZeit]),
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,NewTermZeit, TermZeit, Timestamp);	

		%Sendet das akutelle Mi zur�ck 	
		{tellmi,From} -> 
			Timestamp2 = now(),
			TimeDiff = timer:now_diff(Timestamp2, Timestamp) / 1000,
			NewTermZeit = trunc(TermZeit - TimeDiff),
			From ! Mi,
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,NewTermZeit, TermZeit, Timestamp);

		%Beendet den ggt-Prozess
		kill -> 
			werkzeug:logging(logFileName(MeinName), stringFormat("Downtime: ~p vom Client ~p\r\n", [werkzeug:timeMilliSecond(), MeinName])),
			Namensdienst ! {self(),{unbind,MeinName}}
		
	after
		%Startet Terminierungsanfrage nach Timeout
		TermZeitDauer -> 
			%io:format("Zeit abgelaufen!!!!!!!!!!!!!!!! Nachtbar R = ~p\n", [NeighborR]),

			werkzeug:logging(logFileName(MeinName), stringFormat("~p: initiiere eine Terminierungsabstimmung (~p). ~p\r\n", [MeinName, Mi, werkzeug:timeMilliSecond()])),
			
			NeighborR ! {abstimmung, MeinName},
			%io:format("Prozess ~p startet Terminierungsabstimmung \n", [MeinName]),
			loop(Mi, NeighborL, NeighborR, Namensdienst, KoordName, MeinName, ArbeitsZeit,infinity, TermZeit, Timestamp)
	end.
	

calcGgt(Mi, Y,LeftN, RightN, KoordName, MeinName, ArbeitsZeit) ->
	%io:format("CalcGGT Fun von: ~p  mit Mi = ~p   und Y = ~p \n", [MeinName,Mi,Y]),
	if 
		%Berechnung des neuen Mis
		Y < Mi -> 
			NewMi = ((Mi - 1) rem Y) + 1,
			werkzeug:logging(logFileName(MeinName), stringFormat("sendy: ~p (~p); berechnet als neues Mi ~p. ~p\r\n", [Y, Mi, NewMi, werkzeug:timeMilliSecond()])),
			timer:sleep(ArbeitsZeit),
			CZeit = werkzeug:timeMilliSecond(),
			KoordName ! {briefmi,{MeinName, NewMi, CZeit}},
			LeftN ! {sendy, NewMi},
			RightN ! {sendy, NewMi},
			NewMi;
		true ->
			werkzeug:logging(logFileName(MeinName), stringFormat("sendy: ~p (~p); keine Berechnung.\r\n", [Y, Mi])),
			Mi
	end.
 
 

logFileName(GGTName) ->
		lists:flatten(io_lib:format("log/GGTP_~p~p.log", [GGTName, node()])).

stringFormat(String, Args) ->
	lists:flatten(io_lib:format(String, Args)).
