%%%-------------------------------------------------------------------
%%% @author raphael
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Mar 2018 19:21
%%%-------------------------------------------------------------------

% Run: c(taskOne), c(taskTwo), c(monitor), c(server), taskTwo:testTwo().

-module(taskTwo).
-author("raphael").

-import(server, [serverEstablished/5]).

%% API
-export([lossyNetwork/2, clientStartRobust/2, testTwo/0]).

-define(Timeout, 2000).
-define(Retries, 5).

% Question 1

%% Duplicated server to handle closing connection after Timeout * Retries (2000 * 5 = 100000 ms)
serverStart() -> serverStart(0).
serverStart(ServerSeq) ->
  receive
    {Client, {syn, ClientSeq, _}} ->
      Client ! {self(), {synack, ServerSeq, ClientSeq + 1}},
      receive
        {Client, {ack, NewClientSeq, NewServerSeq}} ->
          NewNewServerSeq = serverEstablished(Client, NewServerSeq, NewClientSeq, "", 0),
          serverStart(NewNewServerSeq)
      after
        ?Timeout * ?Retries -> serverStart(ServerSeq)
      end
  end
.

lossyNetworkStart() ->
  % Wait to be sent the address of the client and the address
  % of the server that I will be monitoring traffic between.
  receive
    {Client, Server} -> lossyNetwork(Client, Server)
  end.

lossyNetwork(Client, Server) ->
  receive
    {Client, TCP} -> faultyLink(Client, Client, Server, TCP, 50);
    {Server, TCP} -> Client ! {self(), TCP}, debug(Client, Server, TCP, false)
  end,
  lossyNetwork(Client, Server)
.

faultyLink(Client, Sender, Target, TCP, Prob) ->
  R = rand:uniform(100),
  if
    R =< Prob -> debug(Client, Sender, TCP, true);
    true -> Target ! {self(), TCP}, debug(Client, Sender, TCP, false)
  end
.

debug(Client, P, TCP, Dropped) ->
  case P == Client of
    true -> io:fwrite("~s> {Client, ~p}~n", [arrow(Dropped), TCP]);
    false -> io:fwrite("<~s {Server, ~p)~n", [arrow(Dropped), TCP])
  end.

arrow(Dropped) ->
  if
    Dropped == true -> "-X-";
    true -> "---"
  end
.

% Question 2

clientStartRobust(Server, Message) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, ServerSeq, ClientSeq}} ->
      NewServerSeq = ServerSeq + 1,
      Server ! {self(), {ack, ClientSeq, NewServerSeq}},

      Status = sendMessage(Server, NewServerSeq, ClientSeq, Message),

      case Status of
        success -> io:format("Client done.~n", []);
        failure -> clientStartRobust(Server, Message)
      end
  after
    ?Timeout -> clientStartRobust(Server, Message)
  end
.

sendMessage(Server, ServerSeq, ClientSeq, Message) -> sendMessage(Server, ServerSeq, ClientSeq, Message, "", 0).

sendMessage(_, _, _, _, _, ?Retries) -> failure;
sendMessage(Server, ServerSeq, ClientSeq, "", "", Tries) ->
  Server ! {self(), {fin, ClientSeq, ServerSeq}},
  receive
    {Server, {ack, ServerSeq, ClientSeq}} -> success
  after
    ?Timeout -> sendMessage(Server, ServerSeq, ClientSeq, "", "", Tries + 1)
  end
;
sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate, Tries) when (length(Candidate) == 7) orelse (length(Message) == 0) ->
  Server ! {self(), {ack, ClientSeq, ServerSeq, Candidate}},
  receive
    {Server, {ack, ServerSeq, NewClientSeq}} ->
      sendMessage(Server, ServerSeq, NewClientSeq, Message, "", 0)
  after
    ?Timeout -> sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate, Tries + 1)
  end
;
sendMessage(Server, ServerSeq, ClientSeq, [Char | Rest], Candidate, Tries) ->
  sendMessage(Server, ServerSeq, ClientSeq, Rest, Candidate ++ [Char], Tries)
.

testTwo() ->
  Server = spawn(fun() -> serverStart() end),
  Monitor = spawn(fun() -> lossyNetworkStart() end),
  Client = spawn(?MODULE, clientStartRobust,
    [Monitor, "A small piece of text"]),
  Monitor ! {Client, Server}
.
