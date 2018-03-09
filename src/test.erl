%%%-------------------------------------------------------------------
%%% @author raphael
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Mar 2018 15:02
%%%-------------------------------------------------------------------
-module(test).
-author("raphael").

%% API
-export([starter/0]).

starter() ->
  Server = spawn(taskOne, serverStart, []),
  _Client1 = spawn(taskOne, clientStart,
    [Server, "The quick brown fox jumped over the lazy dog."]),
  _Client2 = spawn(taskOne, clientStart,
    [Server, "Contrary to popular belief, Lorem Ipsum is not simply random text."]).
