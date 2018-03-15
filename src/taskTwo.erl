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
-import(taskOne, [serverStart/0]).

%% API
-export([lossyNetwork/2, clientStartRobust/2, testTwo/0]).

-define(Timeout, 2000).

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
        success -> io:format("Client done.~n", [])
      end
  after
    ?Timeout -> clientStartRobust(Server, Message)
  end
.

sendMessage(Server, ServerSeq, ClientSeq, Message) -> sendMessage(Server, ServerSeq, ClientSeq, Message, "", false).

sendMessage(Server, ServerSeq, ClientSeq, "", "", FullHandshake) ->
  Server ! {self(), {fin, ClientSeq, ServerSeq}},
  receive
    {Server, {ack, ServerSeq, ClientSeq}} -> success
  after
    ?Timeout -> sendMessage(Server, ServerSeq, ClientSeq, "", "", FullHandshake)
  end
;
sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate, FullHandshake) when (length(Candidate) == 7) orelse (length(Message) == 0) ->
  Server ! {self(), {ack, ClientSeq, ServerSeq, Candidate}},
  receive
    {Server, {ack, ServerSeq, NewClientSeq}} ->
      sendMessage(Server, ServerSeq, NewClientSeq, Message, "", true)
  after
    ?Timeout ->
      if
        FullHandshake == false -> Server ! {self(), {ack, ClientSeq, ServerSeq}};
        true -> null
      end,
      sendMessage(Server, ServerSeq, ClientSeq, Message, Candidate, FullHandshake)
  end
;
sendMessage(Server, ServerSeq, ClientSeq, [Char | Rest], Candidate, FullHandshake) ->
  sendMessage(Server, ServerSeq, ClientSeq, Rest, Candidate ++ [Char], FullHandshake)
.

testTwo() ->
  Server = spawn(taskOne, serverStart, []),
  Monitor = spawn(fun() -> lossyNetworkStart() end),
  Client = spawn(?MODULE, clientStartRobust,
    [Monitor, "Small piece of text"]),
  Monitor ! {Client, Server}
.
