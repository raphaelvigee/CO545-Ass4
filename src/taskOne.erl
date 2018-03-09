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

serverStart() -> serverStart(0).

serverStart(ServerSeq) ->
  receive
    {Client, {syn, ClientSeq, _}} ->
      Client ! {self(), {synack, ServerSeq, ClientSeq + 1}},
      receive
        {Client, {ack, NewClientSeq, NewServerSeq}} ->
          NewNewServerSeq = serverEstablished(Client, NewServerSeq, NewClientSeq, "", 0),
          serverStart(NewNewServerSeq)
      end
  end
.

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
  Monitor ! {Client, Server}
.