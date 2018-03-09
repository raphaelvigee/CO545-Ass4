%%%-------------------------------------------------------------------
%%% @author raphael
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Mar 2018 15:08
%%%-------------------------------------------------------------------

% Run: c(test), c(taskOne), c(monitor), c(server), test:starter().

-module(taskOne).
-author("raphael").

-import(server, [serverEstablished/5]).

%% API
-export([serverStart/0, clientStart/2]).

serverStart() -> serverStart(1).

serverStart(ServerSeq) ->
  receive
    {Client, {syn, ClientSeq, _}} ->
      Client ! {self(), {synack, ServerSeq, ClientSeq + 1}},
      receive
        {Client, {ack, NewClientSeq, ServerSeq}} ->
          NewServerSeq = serverEstablished(Client, ServerSeq, NewClientSeq, "", 0),
          serverStart(NewServerSeq + 1)
      end
  end
.

clientStart(Server, Message) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, ServerSeq, ClientSeq}} ->
      Server ! {self(), {ack, ClientSeq, ServerSeq}},

      sendMessage(Server, ServerSeq, ClientSeq, Message)
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
