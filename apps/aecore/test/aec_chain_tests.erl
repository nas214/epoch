-module(aec_chain_tests).

-include_lib("eunit/include/eunit.hrl").
-include("common.hrl").
-include("blocks.hrl").

genesis_block() ->
    aec_block_genesis:genesis_block_as_deserialized_from_network().

top_test_() ->
    {foreach,
     fun() ->
             {ok, _} = aec_chain:start_link(genesis_block()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop()
     end,
     [{"Initialize chain with genesis block, then check top block with related state trees",
       fun() ->
               GB = genesis_block(),
               ?assertEqual({ok, GB}, aec_chain:top_block()),

               {ok, Top} = aec_chain:top(),
               %% Check block apart from state trees.
               ?assertEqual(GB,
                            aec_blocks:set_trees(Top, aec_blocks:trees(GB))),
               %% Check state trees in block.
               ?assertEqual(aec_blocks:trees(aec_block_genesis:genesis_block()),
                            aec_blocks:trees(Top))
       end}]}.

genesis_test_() ->
    {setup,
     fun() ->
             {ok, _} = aec_chain:start_link(genesis_block()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop()
     end,
     fun() ->
             GB = genesis_block(),
             ?assertEqual({ok, GB}, aec_chain:top_block()),
             GH = aec_blocks:to_header(GB),
             ?assertEqual({ok, GH}, aec_chain:top_header()),

             ?assertEqual({ok, GH}, aec_chain:get_header_by_height(0)),
             ?assertEqual({ok, GB}, aec_chain:get_block_by_height(0)),

             {ok, GHH} = aec_blocks:hash_internal_representation(GB),
             ?assertEqual({ok, GH}, aec_chain:get_header_by_hash(GHH)),
             ?assertEqual({ok, GB}, aec_chain:get_block_by_hash(GHH))
     end}.

header_chain_test_() ->
    {setup,
     fun() ->
             {ok, _} = aec_chain:start_link(genesis_block()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop()
     end,
     fun() ->
             %% Check chain is at genesis.
             B0 = genesis_block(),
             BH0 = aec_blocks:to_header(B0),
             ?assertEqual({ok, BH0}, aec_chain:top_header()),

             %% Check height of genesis - for readability of the test.
             0 = aec_headers:height(BH0),

             %% Add a couple of headers - not blocks - to the chain.
             {ok, B0H} = aec_blocks:hash_internal_representation(B0),
             BH1 = #header{height = 1, prev_hash = B0H},
             ?assertEqual(ok, aec_chain:insert_header(BH1)),
             {ok, B1H} = aec_headers:hash_header(BH1),
             BH2 = #header{height = 2, prev_hash = B1H},
             ?assertEqual(ok, aec_chain:insert_header(BH2)),

             %% Check highest header.
             ?assertEqual({ok, BH2}, aec_chain:top_header()),
             %% Check highest known block - still genesis.
             ?assertEqual({ok, B0}, aec_chain:top_block()),

             %% Check by hash.
             ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
             ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
             ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                          aec_chain:get_block_by_hash(B1H)),
             {ok, B2H} = aec_headers:hash_header(BH2),
             ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                          aec_chain:get_block_by_hash(B2H)),

             %% Check by height.
             ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
             ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
             ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}
                                  }}, aec_chain:get_block_by_height(1)),
             ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}
                                  }}, aec_chain:get_block_by_height(2)),
             ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                     {top_header, BH2}}
                                  }}, aec_chain:get_header_by_height(3)),
             ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                     {top_header, BH2}}
                                  }}, aec_chain:get_block_by_height(3))
     end}.

block_chain_test_() ->
    {foreach,
     fun() ->
             {ok, _} = aec_chain:start_link(genesis_block()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop()
     end,
     [{"Build chain with genesis block plus 2 headers, then store block corresponding to top header",
       fun() ->
               %% Check chain is at genesis.
               B0 = genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a couple of headers - not blocks - to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               B1 = #block{height = 1, prev_hash = B0H},
               BH1 = aec_blocks:to_header(B1),
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               {ok, B1H} = aec_headers:hash_header(BH1),
               B2 = #block{height = 2, prev_hash = B1H},
               BH2 = aec_blocks:to_header(B2),
               ?assertEqual(ok, aec_chain:insert_header(BH2)),

               %% Add one block corresponding to a header already in the chain.
               ?assertEqual(ok, aec_chain:write_block(B2)),

               %% Check highest header.
               ?assertEqual({ok, BH2}, aec_chain:top_header()),
               %% Check highest known block.
               ?assertEqual({ok, B2}, aec_chain:top_block()),

               %% Check by hash.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                            aec_chain:get_block_by_hash(B1H)),
               {ok, B2H} = aec_headers:hash_header(BH2),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
               ?assertEqual({ok, B2}, aec_chain:get_block_by_hash(B2H)),

               %% Check by height.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}
                                    }}, aec_chain:get_block_by_height(1)),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
               ?assertEqual({ok, B2}, aec_chain:get_block_by_height(2)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_header_by_height(3)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_block_by_height(3))
       end},
     {"Build chain with genesis block plus 2 headers, then store block corresponding to header before top header",
       fun() ->
               %% Check chain is at genesis.
               B0 = genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a couple of headers - not blocks - to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               B1 = #block{height = 1, prev_hash = B0H},
               BH1 = aec_blocks:to_header(B1),
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               {ok, B1H} = aec_headers:hash_header(BH1),
               B2 = #block{height = 2, prev_hash = B1H},
               BH2 = aec_blocks:to_header(B2),
               ?assertEqual(ok, aec_chain:insert_header(BH2)),

               %% Add one block corresponding to a header already in the chain.
               ?assertEqual(ok, aec_chain:write_block(B1)),

               %% Check proper state growth
               {ok, {StateHeight, _Trees}} = aec_state:get_trees(),
               ?assertEqual(1, StateHeight),

               %% Check highest header.
               ?assertEqual({ok, BH2}, aec_chain:top_header()),
               %% Check highest known block.
               ?assertEqual({ok, B1}, aec_chain:top_block()),

               %% Check by hash.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
               ?assertEqual({ok, B1}, aec_chain:get_block_by_hash(B1H)),
               {ok, B2H} = aec_headers:hash_header(BH2),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                            aec_chain:get_block_by_hash(B2H)),

               %% Check by height.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
               ?assertEqual({ok, B1}, aec_chain:get_block_by_height(1)),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}
                                    }}, aec_chain:get_block_by_height(2)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_header_by_height(3)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_block_by_height(3))
       end}]}.

fake_genesis_block_with_difficulty() ->
    GB = aec_block_genesis:genesis_block_as_deserialized_from_network(),
    GB#block{target = 1}. %% Field used as if it were difficulty for ease of testing.

get_work_test_() ->
    {foreach,
     fun() ->
             meck:new(aec_headers, [passthrough]),
             meck:expect(
               aec_headers, difficulty,
               fun(#header{target = T}) when is_integer(T) -> float(T) end),
             {ok, _} = aec_chain:start_link(
                         fake_genesis_block_with_difficulty()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop(),
             ?assert(meck:validate(aec_headers)),
             meck:unload(aec_headers)
     end,
     [{"Get work in chain of only genesis",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block_with_difficulty(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check difficulty of genesis - for readability of the test.
               1.0 = aec_headers:difficulty(BH0),

               %% Check work of chain at top.
               ?assertEqual({ok, {1.0, {top_header, BH0}}},
                            aec_chain:get_total_difficulty()),
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               ?assertEqual({ok, {1.0, {top_header, BH0}}},
                            aec_chain:get_total_difficulty_by_hash(B0H))
       end},
      {"Get work in chain of genesis block plus 2 headers",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block_with_difficulty(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check difficulty of genesis - for readability of the test.
               1.0 = aec_headers:difficulty(BH0),

               %% Add a couple of headers to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               BH1 = #header{height = 1, prev_hash = B0H, target = 2},
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               {ok, B1H} = aec_headers:hash_header(BH1),
               BH2 = #header{height = 2, prev_hash = B1H, target = 5},
               ?assertEqual(ok, aec_chain:insert_header(BH2)),

               %% Check work of chain at top.
               ?assertEqual({ok, {8.0, {top_header, BH2}}},
                            aec_chain:get_total_difficulty()),

               %% Check work at each header in the chain.
               {ok, B2H} = aec_headers:hash_header(BH2),
               ?assertEqual({ok, {8.0, {top_header, BH2}}},
                            aec_chain:get_total_difficulty_by_hash(B2H)),
               ?assertEqual({ok, {3.0, {top_header, BH2}}},
                            aec_chain:get_total_difficulty_by_hash(B1H)),
               ?assertEqual({ok, {1.0, {top_header, BH2}}},
                            aec_chain:get_total_difficulty_by_hash(B0H))
       end}]}.

%% Cover unhappy paths not covered in any other tests.
unhappy_paths_test_() ->
    {foreach,
     fun() ->
             {ok, _} = aec_chain:start_link(genesis_block()),
             {ok, _} = aec_state:start_link(),
             ok
     end,
     fun(_) ->
             ok = aec_state:stop(),
             ok = aec_chain:stop()
     end,
     [{"Get header by hash - case not found",
       fun() ->
               %% Check chain is at genesis.
               B0 = genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a header to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               BH1 = #header{height = 1, prev_hash = B0H},
               ?assertEqual(ok, aec_chain:insert_header(BH1)),

               %% Attempt to lookup header not added to chain.
               {ok, B1H} = aec_headers:hash_header(BH1),
               BH2 = #header{height = 2, prev_hash = B1H},
               {ok, B2H} = aec_headers:hash_header(BH2),

               %% Attempt to get by hash header not added to chain.
               ?assertEqual({error, {header_not_found, {top_header, BH1}}},
                            aec_chain:get_header_by_hash(B2H))
       end},
      {"Insert header meant to be successor of top header - case wrong previous hash",
       fun() ->
               %% Check chain is at genesis.
               B0 = genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Attempts to add to the chain at genesis header with
               %% inconsistent previous header fail.
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH0}}},
                            aec_chain:insert_header(BH0)), %% Genesis again.
               ?assertEqual({ok, BH0}, aec_chain:top_header()),
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               BH1 = #header{height = 1, prev_hash = B0H},
               {ok, B1H} = aec_headers:hash_header(BH1),
               BH2 = #header{height = 2, prev_hash = B1H},
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH0}}},
                            aec_chain:insert_header(BH2)), %% Too far ahead.
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Add a header to the chain.
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               ?assertEqual({ok, BH1}, aec_chain:top_header()),

               %% Attempts to add to chain of two blocks with
               %% inconsistent previous header fail.
               {ok, B2H} = aec_headers:hash_header(BH2),
               BH3 = #header{height = 3, prev_hash = B2H},
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(BH3)), %% Too far ahead.
               ?assertEqual({ok, BH1}, aec_chain:top_header()),
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(BH0)), %% Genesis again.
               ?assertEqual({ok, BH1}, aec_chain:top_header()),
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(BH1)), %% Block 1 again.
               ?assertEqual({ok, BH1}, aec_chain:top_header()),
               ?assertEqual({error, {previous_hash_is_not_top,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(
                              #header{height = 2, prev_hash = B0H})), %% Previous hash to to 2 block headers ago.
               ?assertEqual({ok, BH1}, aec_chain:top_header())
       end},
      {"Insert header meant to be successor of top header - case correct previous hash but wrong height",
       fun() ->
               %% Check chain is at genesis.
               B0 = genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Attempts to add to the chain at genesis header with
               %% inconsistent height fail.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               ?assertEqual({error, {height_inconsistent_with_previous_hash,
                                     {top_header, BH0}}},
                            aec_chain:insert_header(
                              #header{height = 2, prev_hash = B0H})),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),
               ?assertEqual({error, {height_inconsistent_with_previous_hash,
                                     {top_header, BH0}}},
                            aec_chain:insert_header(
                              #header{height = 0, prev_hash = B0H})),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Add a header to the chain.
               BH1 = #header{height = 1, prev_hash = B0H},
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               ?assertEqual({ok, BH1}, aec_chain:top_header()),

               %% Attempts to add to chain of two blocks with
               %% inconsistent height fail.
               {ok, B1H} = aec_headers:hash_header(BH1),
               ?assertEqual({error, {height_inconsistent_with_previous_hash,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(
                              #header{height = 3, prev_hash = B1H})),
               ?assertEqual({ok, BH1}, aec_chain:top_header()),
               ?assertEqual({error, {height_inconsistent_with_previous_hash,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(
                              #header{height = 1, prev_hash = B1H})),
               ?assertEqual({ok, BH1}, aec_chain:top_header()),
               ?assertEqual({error, {height_inconsistent_with_previous_hash,
                                     {top_header, BH1}}},
                            aec_chain:insert_header(
                              #header{height = 0, prev_hash = B1H})),
               ?assertEqual({ok, BH1}, aec_chain:top_header())
       end}]}.

extend_block_chain_by_difficulties_with_nonce_and_coinbase(
  PreviousBlock,
  Difficulties, Nonce) ->
    {ok, MinerAccount} = aec_keys:pubkey(),
    extend_block_chain_by_difficulties_with_nonce_and_coinbase(
      PreviousBlock, Difficulties, Nonce,
      MinerAccount).

extend_block_chain_by_difficulties_with_nonce_and_coinbase(
  PreviousBlock,
  Difficulties, Nonce,
  MinerAccount) ->
    [PreviousBlock | BlockChainExtension] =
        lists:reverse(
          lists:foldl(
            fun(D, [PrevB | _] = BC) ->
                    B = next_block_by_difficulty_with_nonce_and_coinbase(
                          PrevB,
                          D, Nonce,
                          MinerAccount),
                    [B | BC]
            end,
            [PreviousBlock],
            Difficulties)),
    BlockChainExtension.

next_block_by_difficulty_with_nonce_and_coinbase(PreviousBlock,
                                                 Difficulty, Nonce,
                                                 MinerAccount) ->
    {ok, PreviousHash} = aec_blocks:hash_internal_representation(PreviousBlock),
    H = 1 + aec_blocks:height(PreviousBlock),
    #block{height = H,
           prev_hash = PreviousHash,
           target = Difficulty,
           nonce = Nonce,
           txs = [signed_coinbase_tx(MinerAccount, H)]}.

signed_coinbase_tx(Account, _AccountNonce) ->
    {ok, Tx} = aec_coinbase_tx:new(#{account => Account},
                                   unused_state_trees_argument),
    {ok, STx} = aec_keys:sign(Tx),
    STx.

header_chain_from_block_chain(BC) ->
    lists:map(fun aec_blocks:to_header/1, BC).

longest_header_chain_test_() ->
    {foreach,
     fun() ->
             meck:new(aec_headers, [passthrough]),
             meck:new(aec_blocks, [passthrough]),
             meck:expect(
               aec_headers, difficulty,
               fun(#header{target = T}) when is_integer(T) -> float(T) end),
             meck:expect(
               aec_blocks, difficulty,
               fun(#block{target = T}) when is_integer(T) -> float(T) end),
             {ok, _} = aec_chain:start_link(
                         fake_genesis_block_with_difficulty()),
             {ok, _} = aec_state:start_link(),
             %% Start `aec_keys` merely for generating realistic chain
             %% with test signed coinbase txs - as a node would do.
             _TmpKeysDir = aec_keys_setup()
     end,
     fun(TmpKeysDir) ->
             ok = aec_keys_cleanup(TmpKeysDir),
             ok = aec_state:stop(),
             ok = aec_chain:stop(),
             ?assert(meck:validate(aec_blocks)),
             ?assert(meck:validate(aec_headers)),
             meck:unload(aec_blocks),
             meck:unload(aec_headers)
     end,
     [{"The alternative header chain has a different genesis hence its amount of work cannot be compared",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block_with_difficulty(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),
               %% Check nonce of genesis - for readability of the test.
               0 = aec_headers:nonce(BH0),

               %% Generate the alternative header chain from a
               %% different genesis.
               HA0 = BH0#header{nonce = 1},
               {ok, HA0H} = aec_headers:hash_header(HA0),
               HA1 = #header{height = 1, prev_hash = HA0H},
               AltHC = [HA0, HA1],

               %% Attempt to determine chain with more work -
               %% specifying full header chain.
               ?assertEqual({error, {different_genesis, {genesis_header, BH0}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({error, {no_common_ancestor, {top_header, BH0}}},
                            aec_chain:has_more_work(
                              [HA1] = lists:nthtail(1, AltHC))),

               %% Check top.
               ?assertEqual({ok, BH0}, aec_chain:top_header())
       end},
      {"The alternative header chain does not have more work - case alternative chain is less high",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [2, 2], 111)],
               AltBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [3], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {false, {{{top_chain_work, 5.0},
                                           {alt_chain_work, 4.0}},
                                          {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {false, {{{top_chain_work, 5.0},
                                           {alt_chain_work, 4.0}},
                                          {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Give up updating chain because existing chain has more work.
               ok
       end},
      {"The alternative header chain does not have more work - case alternative chain is higher",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [3], 111)],
               AltBC = [_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 222)],
               MainHC = [H0, HM1] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM1}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {false, {{{top_chain_work, 4.0},
                                           {alt_chain_work, 3.0}},
                                          {top_header, HM1}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {false, {{{top_chain_work, 4.0},
                                           {alt_chain_work, 3.0}},
                                          {top_header, HM1}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Give up updating chain because existing chain has more work.
               ok
       end},
      {"The alternative chain has the same amount of work, hence is to be ignored because received later",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [2], 111)],
               AltBC = [_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 222)],
               MainHC = [H0, HM1] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM1}, aec_chain:top_header()),

               %% Attempt to determine chain with more work -
               %% specifying full header chain.
               ?assertEqual({ok, {false, {{{top_chain_work, 3.0},
                                           {alt_chain_work, 3.0}},
                                          {top_header, HM1}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {false, {{{top_chain_work, 3.0},
                                           {alt_chain_work, 3.0}},
                                          {top_header, HM1}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Give up updating chain because existing chain has same work.
               ok
       end},
      {"The alternative header chain has more work - case alternative chain is higher. Force chain excluding genesis.",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [2], 111)],
               AltBC = [_,_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 1], 222)],
               MainHC = [H0, HM1] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM1}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM1}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM1}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update chain because existing chain has less work.
               ?assertEqual({ok, {{old_top_header, HM1},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(
                              lists:nthtail(1, AltHC))),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),

               %% Check that headers in previous chain cannot be
               %% retrieved by hash; i.e. chain service minimizes used
               %% storage while exposing consistent view of chain.
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end},
      {"The alternative header chain has more work - case alternative chain is higher. Force chain including genesis.",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [2], 111)],
               AltBC = [_,_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 1], 222)],
               MainHC = [H0, HM1] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM1}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM1}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM1}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update chain because existing chain has less work.
               ?assertEqual({ok, {{old_top_header, HM1},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),

               %% Check that headers in previous chain cannot be
               %% retrieved by hash; i.e. chain service minimizes used
               %% storage while exposing consistent view of chain.
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end},
      {"The alternative header chain has more work - case alternative chain is less high",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 111)],
               AltBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [3], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, HA1] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update chain because existing chain has less work.
               ?assertEqual({ok, {{old_top_header, HM2},
                                  {new_top_header, HA1}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA1}, aec_chain:top_header()),

               %% Check that headers in previous chain cannot be
               %% retrieved by hash; i.e. chain service minimizes used
               %% storage while exposing consistent view of chain.
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA1}}},
                                      aec_chain:get_header_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end},
      {"The alternative chain initially has more work, but concurrent insertion in chain service makes it not have more work any longer. I.e. concurrent insertions in the chain service do not result in sub-optimal choice.",
       fun() ->
               %% This test has the main aim of clarifying design of
               %% whether chain service shall reject forcing chain
               %% with less work.

               %% Generate the two header chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_,_,_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 2], 111)],
               AltBC = [_,_] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [3], 222)],
               _MainHC = [H0, HM1, HM2, HM3] = header_chain_from_block_chain(MainBC),
               InitialMainHC = [H0, HM1, HM2],
               AltHC = [H0, _] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the initial part of the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, InitialMainHC)),
               ?assertEqual({ok, HM2}, aec_chain:top_header()),

               %% Determine chain with more work.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),

               %% Decide to update chain because existing chain has
               %% less work.

               %% Concurrent actor increases amount of work in tracked
               %% chain.
               ok = aec_chain:insert_header(HM3),
               ?assertEqual({ok, HM3}, aec_chain:top_header()),

               %% Based on past - now obsolete - decision, update
               %% chain.  Chain service rejects.
               ?assertEqual({error, {chain_does_not_have_more_work,
                                     {{{top_chain_work, 5.0},
                                       {alt_chain_work, 4.0}},
                                      {top_header, HM3}}}},
                            aec_chain:force_insert_headers(AltHC)),
               ?assertEqual({ok, HM3}, aec_chain:top_header())
       end}]}.

longest_block_chain_test_() ->
    {foreach,
     fun() ->
             meck:new(aec_headers, [passthrough]),
             meck:new(aec_blocks, [passthrough]),
             meck:expect(
               aec_headers, difficulty,
               fun(#header{target = T}) when is_integer(T) -> float(T) end),
             meck:expect(
               aec_blocks, difficulty,
               fun(#block{target = T}) when is_integer(T) -> float(T) end),
             {ok, _} = aec_chain:start_link(
                         fake_genesis_block_with_difficulty()),
             {ok, _} = aec_state:start_link(),
             %% Start `aec_keys` merely for generating realistic chain
             %% with test signed coinbase txs - as a node would do.
             _TmpKeysDir = aec_keys_setup()
     end,
     fun(TmpKeysDir) ->
             ok = aec_keys_cleanup(TmpKeysDir),
             ok = aec_state:stop(),
             ok = aec_chain:stop(),
             ?assert(meck:validate(aec_blocks)),
             ?assert(meck:validate(aec_headers)),
             meck:unload(aec_blocks),
             meck:unload(aec_headers)
     end,
     [{"The alternative block chain has more work - case both main and alternative chains with all blocks. Only genesis block in common.",
       fun() ->
               %% Generate the two block chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_, _, B2] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 111)],
               AltBC = [_, _, _, BA3] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 1], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is at genesis.
               S0 = aec_blocks:trees(aec_block_genesis:genesis_block()),
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),
               ?assertMatch({ExpH, {ok, {ExpH, _}}},
                            {aec_blocks:height(B0), aec_state:get_trees()}),

               %% Insert the main block chain.
               lists:foreach(
                 fun({H, B}) ->
                         ok = aec_chain:insert_header(H),
                         ?assertEqual(ok, aec_chain:write_block(B))
                 end,
                 lists:nthtail(1, lists:zip(MainHC, MainBC))),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),
               ?assertEqual({ok, B2}, aec_chain:top_block()),

               %% Check state of the world changed ...
               MainTop = aec_chain_top_ok(),
               ?assertNotEqual(aec_blocks:set_trees(B0, S0), MainTop),
               %% ... and it is at highest block of main chain.
               ?assertEqual(B2, aec_blocks:set_trees(MainTop,
                                                     aec_blocks:trees(B2))),
               ?assertMatch({ExpH, {ok, {ExpH, _}}},
                            {aec_blocks:height(B2), aec_state:get_trees()}),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update header chain because existing chain has less
               %% work.
               ?assertEqual({ok, {{old_top_header, HM2},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is back to genesis.
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),
               ?assertMatch({ExpH, {ok, {ExpH, _}}},
                            {aec_blocks:height(B0), aec_state:get_trees()}),

               %% Insert all blocks for new chain.
               lists:foreach(
                 fun(B) -> ?assertEqual(ok, aec_chain:write_block(B)) end,
                 lists:nthtail(1, AltBC)),

               %% Check top block changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, BA3}, aec_chain:top_block()),

               %% Check state of the world changed ...
               AltTop = aec_chain_top_ok(),
               ?assertNotEqual(aec_blocks:set_trees(B0, S0), AltTop),
               %% ... and it is at highest block of alternative chain.
               ?assertEqual(BA3, aec_blocks:set_trees(AltTop,
                                                      aec_blocks:trees(BA3))),
               ?assertMatch({ExpH, {ok, {ExpH, _}}},
                            {aec_blocks:height(BA3), aec_state:get_trees()}),

               %% Check that headers and blocks in previous chain
               %% cannot be retrieved by hash; i.e. chain service
               %% minimizes used storage while exposing consistent
               %% view of chain."
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH)),
                         ?assertEqual({error, {block_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_block_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end},
      {"The alternative block chain has more work - case both main and alternative chains with all blocks. Two blocks in common.",
       fun() ->
               %% Generate the two block chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_, B1, B2] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 111)],
               AltBC = [_, _, _, BA3] = [B0, B1 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B1, [1, 1], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is at genesis.
               S0 = aec_blocks:trees(aec_block_genesis:genesis_block()),
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Insert the main block chain.
               lists:foreach(
                 fun({H, B}) ->
                         ok = aec_chain:insert_header(H),
                         ?assertEqual(ok, aec_chain:write_block(B))
                 end,
                 lists:nthtail(1, lists:zip(MainHC, MainBC))),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),
               ?assertEqual({ok, B2}, aec_chain:top_block()),

               %% Check state of the world changed ...
               MainTop = aec_chain_top_ok(),
               ?assertNotEqual(aec_blocks:set_trees(B0, S0), MainTop),
               %% ... and it is at highest block of main chain.
               ?assertEqual(B2, aec_blocks:set_trees(MainTop,
                                                     aec_blocks:trees(B2))),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(2, AltHC))),

               %% Update header chain because existing chain has less
               %% work.
               ?assertEqual({ok, {{old_top_header, HM2},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, B1}, aec_chain:top_block()),

               %% Check state of the world changed ...
               timer:sleep(1000), %% TODO Make this event driven.
               AltHsTop = aec_chain_top_ok(),
               ?assertNotEqual(MainTop, AltHsTop),
               %% ... and it is back to highest common ancestor.
               ?assertEqual(B1, aec_blocks:set_trees(AltHsTop,
                                                     aec_blocks:trees(B1))),

               %% Insert all blocks for new chain.
               lists:foreach(
                 fun(B) -> ?assertEqual(ok, aec_chain:write_block(B)) end,
                 lists:nthtail(2, AltBC)),

               %% Check top block changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, BA3}, aec_chain:top_block()),

               %% Check state of the world changed ...
               AltTop = aec_chain_top_ok(),
               ?assertNotEqual(AltHsTop, AltTop),
               %% ... and it is at highest block of alternative chain.
               ?assertEqual(BA3, aec_blocks:set_trees(AltTop,
                                                      aec_blocks:trees(BA3))),

               %% Check that headers and blocks in previous chain
               %% cannot be retrieved by hash; i.e. chain service
               %% minimizes used storage while exposing consistent
               %% view of chain."
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH)),
                         ?assertEqual({error, {block_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_block_by_hash(HH))
                 end,
                 lists:nthtail(2, MainHC))
       end},
      {"The alternative block chain has more work - case main chain with only block corresponding to top header (not contiguous to genesis), and alternative chain with only block corresponding to top header (not contiguous to genesis). Only genesis block in common.",
       fun() ->
               %% Generate the two block chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_, _, B2] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 111)],
               AltBC = [_, _, _, BA3] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 1], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is at genesis.
               S0 = aec_blocks:trees(aec_block_genesis:genesis_block()),
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Insert the main header chain...
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),
               %% ... and a block corresponding to a header already in
               %% the chain (not contiguous to genesis).
               ?assertEqual(ok, aec_chain:write_block(B2)),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),
               ?assertEqual({ok, B2}, aec_chain:top_block()),

               %% Check state of the world is still at genesis.
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update header chain because existing chain has less
               %% work.
               ?assertEqual({ok, {{old_top_header, HM2},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is still at genesis.
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Insert only block corresponding to top header (not
               %% contiguous to genesis).
               ?assertEqual(ok, aec_chain:write_block(BA3)),

               %% Check top block changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, BA3}, aec_chain:top_block()),

               %% Check state of the world is still at genesis.
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Check that headers and blocks in previous chain
               %% cannot be retrieved by hash; i.e. chain service
               %% minimizes used storage while exposing consistent
               %% view of chain."
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH)),
                         ?assertEqual({error, {block_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_block_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end},
      {"The alternative block chain has more work - case main chain with only one block contiguous to genesis, and alternative chain with two blocks contiguous to genesis. Only genesis block in common.",
       fun() ->
               %% Generate the two block chains.
               B0 = fake_genesis_block_with_difficulty(),
               0 = aec_blocks:height(B0), %% For readability of the test.
               1.0 = aec_blocks:difficulty(B0), %% For readability of the test.
               MainBC = [_, B1, _] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1], 111)],
               AltBC = [_, BA1, BA2, _] = [B0 | extend_block_chain_by_difficulties_with_nonce_and_coinbase(B0, [1, 1, 1], 222)],
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _, _, HA3] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is at genesis.
               S0 = aec_blocks:trees(aec_block_genesis:genesis_block()),
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Insert the main header chain...
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),
               %% ... and a block corresponding to a header already in
               %% the chain (contiguous to genesis).
               ?assertEqual(ok, aec_chain:write_block(B1)),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),
               ?assertEqual({ok, B1}, aec_chain:top_block()),

               %% Check state of the world changed ...
               MainTop = aec_chain_top_ok(),
               ?assertNotEqual(aec_blocks:set_trees(B0, S0), MainTop),
               %% ... and it is at highest block of main chain.
               ?assertEqual(B1, aec_blocks:set_trees(MainTop,
                                                     aec_blocks:trees(B1))),

               %% Determine chain with more work - specifying full
               %% header chain.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({ok, {true, {{{top_chain_work, 3.0},
                                          {alt_chain_work, 4.0}},
                                         {top_header, HM2}}}},
                            aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Update header chain because existing chain has less
               %% work.
               ?assertEqual({ok, {{old_top_header, HM2},
                                  {new_top_header, HA3}}},
                            aec_chain:force_insert_headers(AltHC)),

               %% Check top changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, B0}, aec_chain:top_block()),

               %% Check state of the world is back to genesis.
               ?assertEqual(aec_blocks:set_trees(B0, S0), aec_chain_top_ok()),

               %% Insert two blocks contiguous to genesis.
               ?assertEqual(ok, aec_chain:write_block(BA2)),
               ?assertEqual(ok, aec_chain:write_block(BA1)),

               %% Check top block changed.
               ?assertEqual({ok, HA3}, aec_chain:top_header()),
               ?assertEqual({ok, BA2}, aec_chain:top_block()),

               %% Check state of the world changed ...
               AltTop = aec_chain_top_ok(),
               ?assertNotEqual(aec_blocks:set_trees(B0, S0), AltTop),
               %% ... and it is at highest block of alternative chain.
               ?assertEqual(BA2, aec_blocks:set_trees(AltTop,
                                                      aec_blocks:trees(BA2))),

               %% Check that headers and blocks in previous chain
               %% cannot be retrieved by hash; i.e. chain service
               %% minimizes used storage while exposing consistent
               %% view of chain."
               lists:foreach(
                 fun(H) ->
                         {ok, HH} = aec_headers:hash_header(H),
                         ?assertEqual({error, {header_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_header_by_hash(HH)),
                         ?assertEqual({error, {block_not_found,
                                               {top_header, HA3}}},
                                      aec_chain:get_block_by_hash(HH))
                 end,
                 lists:nthtail(1, MainHC))
       end}]}.

aec_chain_top_ok() ->
    {ok, T} = aec_chain:top(),
    T.

aec_keys_setup() ->
    TmpKeysDir = mktempd(),
    ok = application:ensure_started(crypto),
    {ok, _} = aec_keys:start_link(["mypassword", TmpKeysDir]),
    TmpKeysDir.

aec_keys_cleanup(TmpKeysDir) ->
    ok = aec_keys:stop(),
    ok = application:stop(crypto),
    {ok, KeyFiles} = file:list_dir(TmpKeysDir),
    %% Expect two filenames - private and public keys.
    [_KF1, _KF2] = KeyFiles,
    lists:foreach(
      fun(F) ->
              AbsF = filename:absname_join(TmpKeysDir, F),
              {ok, _} = {file:delete(AbsF), {F, AbsF}}
      end,
      KeyFiles),
    ok = file:del_dir(TmpKeysDir).

mktempd() ->
    mktempd(os:type()).

mktempd({unix, _}) ->
    lib:nonl(?cmd("mktemp -d")).
