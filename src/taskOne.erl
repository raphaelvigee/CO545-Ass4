%%%-------------------------------------------------------------------
%%% @author raphael
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Mar 2018 15:08
%%%-------------------------------------------------------------------

% Run: c(test), c(taskOne), c(monitor), c(server), taskOne:testOne().

-module(taskOne).
-author("raphael").

-import(server, [serverEstablished/5]).
-import(monitor, [tcpMonitorStart/0]).

%% API
-export([serverStart/0, clientStart/2, testOne/0]).

% Question 1

serverStart() -> serverStart(0, #{}).

serverStart(ServerSeq, ClientServerMap) ->
  Server = self(),
  receive
    {Client, {syn, ClientSeq, _}} ->
      RequestThread = spawn(fun() -> requestHandler(Client, Server, ClientSeq, ServerSeq) end),
      io:format("RequestThread: ~p~n", [RequestThread]),
      serverStart(ServerSeq, [{Client, RequestThread} | ClientServerMap]);
    {Client, TCP} ->
      T = get(ClientServerMap, Client),
      io:format("Forward Target: ~p~n", [T]),
      T ! {Client, TCP},
      serverStart(ServerSeq, ClientServerMap);
    X -> io:format("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX Other: ~p~n", [X])
  end
.

requestHandler(Client, Server, ClientSeq, ServerSeq) ->
  Client ! {Server, {synack, ServerSeq, ClientSeq + 1}},
  receive
    {Client, {ack, NewClientSeq, NewServerSeq}} ->
      io:format("Request handler: ~p~n", [{Client, {ack, NewClientSeq, NewServerSeq}}]),
      serverEstablished(Client, NewServerSeq, NewClientSeq, "", 0)
  end
.

get([], _) -> null;
get([{Key, V} | _], Key) -> V;
get([_ | R], Key) -> get(R, Key).

% Question 2

clientStart(Server, Message) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, ServerSeq, ClientSeq}} ->
      NewServerSeq = ServerSeq + 1,
      Server ! {self(), {ack, ClientSeq, NewServerSeq}},

      sendMessage(Server, NewServerSeq, ClientSeq, Message)
  end
.

sendMessage(Server, ServerSeq, ClientSeq, Message) -> sendMessage(Server, ServerSeq, ClientSeq, Message, "").

sendMessage(Server, ServerSeq, ClientSeq, "", "") ->
  Server ! {self(), {fin, ClientSeq, ServerSeq}},
  receive
    {Server, {ack, ServerSeq, ClientSeq}} -> io:format("Client done.~n", [])
  end
;
sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate) when (length(Candidate) == 7) orelse (length(Message) == 0) ->
  Server ! {self(), {ack, ClientSeq, ServerSeq, Candidate}},
  receive
    {Server, {ack, ServerSeq, NewClientSeq}} ->
      sendMessage(Server, ServerSeq, NewClientSeq, Message, "")
  end
;
sendMessage(Server, ServerSeq, ClientSeq, [Char | Rest], Candidate) ->
  sendMessage(Server, ServerSeq, ClientSeq, Rest, Candidate ++ [Char])
.

% Question 3
% The monitor is acting like a client and a server, if it receives a message from the client, it forwards it to the server, if it receives one from the server it forwards it to the client

% Question 4

testOne() ->
  Server = spawn(?MODULE, serverStart, []),
  Monitor = spawn(monitor, tcpMonitorStart, []),
  Client = spawn(?MODULE, clientStart,
    [Monitor, "A small piece of text"]),
  Monitor ! {Client, Server},
  io:format("#### Server: ~p~n", [Server]),
  io:format("#### Monitor: ~p~n", [Monitor]),
  io:format("#### Client: ~p~n", [Client])
.
