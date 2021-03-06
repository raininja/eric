-module(eric_log).
-behaviour(gen_event).

-export([init/1, handle_event/2, handle_call/2, handle_info/2, code_change/3, terminate/2]).

init(State) ->
  {ok, State}.

% Ping Pong
handle_event({response, [_, _, ping, Host]}, State) ->
  eric:send("PING :" ++ binary_to_list(Host)),
  {ok, State};

handle_event({response, [_, _, pong, _, _]}, State) ->
  {ok, State};

% PrivMsg
handle_event({response, [From, _, privmsg, To, Message]}, State) ->
  io:format("[~s] <~s> ~s ~n", [
    color:yellowb(binary_to_list(To)),
    binary_to_list(From),
    binary_to_list(Message)
  ]),
  {ok, State};

% JOIN
handle_event({response, [From, _, join, Channel, _]}, State) ->
  io:format("[~s] ~s has joined ~s ~n", [
    color:blueb("join"),
    color:whiteb(binary_to_list(From)),
    color:whiteb(binary_to_list(Channel))
  ]),
  {ok, State};

% PART
handle_event({response, [From, _, part, Channel, _]}, State) ->
  io:format("[~s] ~s left ~s ~n", [
    color:blueb("part"),
    color:whiteb(binary_to_list(From)),
    color:whiteb(binary_to_list(Channel))
  ]),
  {ok, State};

% JOIN
handle_event({response, [From, _, quit, Msg]}, State) ->
  io:format("[~s] ~s has quit - ~s ~n", [
    color:blueb("quit"),
    binary_to_list(From),
    color:whiteb(binary_to_list(Msg))
  ]),
  {ok, State};

% TOPIC
handle_event({response, [_, _, rpl_topic, _, Channel, Topic]}, State) ->
  print_topic(Channel, Topic),
  {ok, State};

handle_event({response, [From, _, topic, Channel, Topic]}, State) ->
  print_topic(From, Channel, Topic),
  {ok, State};

% NAMES
handle_event({response, [_, _, rpl_namreply, _, _, Channel, Names]}, State) ->
  io:format("[~s] ~s: ~s ~n", [
    color:blueb("names"),
    color:whiteb(binary_to_list(Channel)),
    binary_to_list(Names)
  ]),
  {ok, State};

handle_event({response, [_, _, rpl_endofnames, _, Channel, Msg]}, State) ->
  io:format("[~s] ~s: ~s ~n", [
    color:blueb("names"),
    color:whiteb(binary_to_list(Channel)),
    binary_to_list(Msg)
  ]),
  {ok, State};

% NOTICE
handle_event({response, [_, _, notice, _, Msg]}, State) ->
  print_notice(Msg),
  {ok, State};

% MODE
handle_event({response, [_, _, mode, Nick, Mode]}, State) ->
  io:format("[~s] ~s sets mode ~s ~n", [color:yellowb("mode"), binary_to_list(Nick), binary_to_list(Mode)]),
  {ok, State};

% MOTD
handle_event({response, [_, _, rpl_motdstart, _, Msg]}, State) ->
  print_motd(Msg),
  {ok, State};

handle_event({response, [_, _, rpl_motd, _, Msg]}, State) ->
  print_motd(Msg),
  {ok, State};

handle_event({response, [_, _, rpl_endofmotd, _, Msg]}, State) ->
  print_motd(Msg),
  {ok, State};

% NICK
handle_event({response, [Nick, _, nick, NewNick]}, State) ->
  io:format("[~s] ~s is now known as ~s ~n", [
    color:blueb("nick"), 
    color:whiteb(binary_to_list(Nick)),
    color:whiteb(binary_to_list(NewNick))
  ]),
  {ok, State};

handle_event({response, [_, _, err_nicknameinuse, _, Nick, Message]}, State) ->
  io:format("[~s] ~s - ~s ~n", [
    color:blueb("nick"), 
    color:whiteb(binary_to_list(Nick)),
    binary_to_list(Message)
  ]),
  {ok, State};

% KICK
handle_event({response, [Op, _, kick, Channel, Nick, Reason]}, State) ->
  io:format("[~s] ~s was kicked from ~s by ~s [~s] ~n", [
    color:blueb("kick"),
    color:whiteb(binary_to_list(Nick)),
    color:whiteb(binary_to_list(Channel)),
    color:whiteb(binary_to_list(Op)),
    color:whiteb(binary_to_list(Reason))
  ]),
  {ok, State};

% WHOIS
handle_event({response, [_, _, rpl_whoisuser, _, Nick, Username, Host, _, Realname]}, State) ->
  io:format("[~s] ~s <~s@~s> ~n", [
    color:redb("whois"),
    color:whiteb(binary_to_list(Nick)),
    binary_to_list(Username),
    binary_to_list(Host)
  ]),
  print_whois(realname, Realname),
  {ok, State};

handle_event({response, [_, _, rpl_whoisserver, _, _, Server, Location]}, State) ->
  print_whois(server, Server, Location),
  {ok, State};

handle_event({response, [_, _, rpl_whoischannels, _, _, Channels]}, State) ->
  print_whois(channels, Channels),
  {ok, State};

handle_event({response, [_, _, rpl_whoissecure, _, _, Msg]}, State) ->
  print_whois("secure", Msg),
  {ok, State};

handle_event({response, [_, _, rpl_whoishost, _, _, Msg]}, State) ->
  print_whois("hostname", Msg),
  {ok, State};

handle_event({response, [_, _, rpl_whoisidle, _, _, Idle, _, _]}, State) ->
  Seconds = list_to_binary(" seconds"),
  print_whois("idle", <<Idle/binary, Seconds/binary>>),
  {ok, State};

handle_event({response, [_, _, rpl_whoisaccount, _, _, Account, Msg]}, State) ->
  print_whois("account", Msg, Account),
  {ok, State};

handle_event({response, [_, _, err_nosuchnick, _, Nick, Msg]}, State) ->
  io:format("[~s] ~s ~s ~n", [
    color:redb("whois"),
    color:whiteb(binary_to_list(Nick)),
    binary_to_list(Msg)
  ]),
  {ok, State};

handle_event({response, [_, _, rpl_endofwhois, _, _, Msg]}, State) ->
  io:format("[~s] ~s ~n", [color:redb("whois"), binary_to_list(Msg)]),
  {ok, State};

% Error
handle_event({response, [_, _, error, Error]}, State) ->
  io:format("[~s] ~s ~n",  [color:redb("error"), binary_to_list(Error)]),
  {ok, State};

% Everything else
handle_event({response, Data}, State) ->
  io:format("[~s] ~p ~n", [color:cyanb("unknown"), Data]),
  {ok, State};

handle_event(_, State) ->
  {ok, State}.

handle_call(_, State) ->
  {ok, ok, State}.

handle_info(_, State) ->
  {ok, State}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(_Reason, _State) ->
  ok.

% Helper funcs
print_motd(Msg) ->
  io:format("[~s] ~s ~n", [color:magentab("motd"), binary_to_list(Msg)]).

print_notice(Msg) ->
  io:format("[~s] ~s ~n", [color:greenb("notice"), binary_to_list(Msg)]).

print_topic(Channel, Topic) ->
  io:format("[~s] ~s: ~s ~n", [
      color:blueb("topic"),
      color:whiteb(binary_to_list(Channel)),
      binary_to_list(Topic)
    ]
  ).

print_topic(From, Channel, Topic) ->
  io:format("[~s] ~s by ~s: ~s ~n", [
      color:blueb("topic"),
      color:whiteb(binary_to_list(Channel)),
      color:whiteb(binary_to_list(From)),
      binary_to_list(Topic)
    ]
  ).

print_whois(Item, Value) ->
  io:format("[~s] ~s\t: ~s ~n", [
      color:redb("whois"),
      Item,
      binary_to_list(Value)
    ]
  ).

print_whois(Item, Value, Value2) ->
  io:format("[~s] ~s\t: ~s ~s ~n", [
      color:redb("whois"),
      Item,
      binary_to_list(Value),
      color:whiteb(binary_to_list(Value2))
    ]
  ).
