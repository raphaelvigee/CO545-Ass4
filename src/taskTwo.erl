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

-import(taskOne, [serverStart/0]).

%% API
-export([lossyNetwork/2, clientStartRobust/2, testTwo/0]).

% Question 1

lossyNetworkStart() ->
  % Wait to be sent the address of the client and the address
  % of the server that I will be monitoring traffic between.
  receive
    {Client, Server} -> lossyNetwork(Client, Server)
  end.

lossyNetwork(Client, Server) ->
  receive
    {Client, TCP} -> faultyLink(Client, Client, Server, TCP, 50);
    {Server, TCP} -> Client ! {self(), TCP}, debug(Client, Client, TCP, false)
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
    Dropped == true -> "~~~";
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

      sendMessage(Server, NewServerSeq, ClientSeq, Message)
  after
    2000 -> clientStartRobust(Server, Message)
  end
.

sendMessage(Server, ServerSeq, ClientSeq, Message) -> sendMessage(Server, ServerSeq, ClientSeq, Message, "").

sendMessage(Server, ServerSeq, ClientSeq, "", "") ->
  Server ! {self(), {fin, ClientSeq, ServerSeq}},
  receive
    {Server, {ack, ServerSeq, ClientSeq}} -> io:format("Client done.~n", [])
  after
    2000 -> sendMessage(Server, ServerSeq, ClientSeq, "", "")
  end
;
sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate) when (length(Candidate) == 7) orelse (length(Message) == 0) ->
  Server ! {self(), {ack, ClientSeq, ServerSeq, Candidate}},
  receive
    {Server, {ack, ServerSeq, NewClientSeq}} ->
      sendMessage(Server, ServerSeq, NewClientSeq, Message, "")
  after
    2000 -> sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate)
  end
;
sendMessage(Server, ServerSeq, ClientSeq, [Char | Rest], Candidate) ->
  sendMessage(Server, ServerSeq, ClientSeq, Rest, Candidate ++ [Char])
.

testTwo() ->
  Server = spawn(taskOne, serverStart, []),
  Monitor = spawn(fun() -> lossyNetworkStart() end),
  Client = spawn(?MODULE, clientStartRobust,
    [Monitor, "A small piece of text"]),
  Monitor ! {Client, Server}
.
