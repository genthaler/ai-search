module Search
    exposing
        ( Node
        , SearchResult(..)
        , Step
        , Uninformed
        , breadthFirstSearch
        , depthFirstSearch
        , next
        , nextGoal
        )

{-|

# Input types for searches:
@docs Node, Step, Uninformed

# The search output type:
@docs SearchResult

# Helper functions for iterating searches to produce results:
@docs next, nextGoal

# Search strategies:
@docs breadthFirstSearch, depthFirstSearch
-}


{-| Defines the type of Nodes that searches work over.
-}
type alias Node state =
    ( state, Bool )


{-| Defines the possible outcomes of a search.
-}
type SearchResult state
    = Complete
    | Goal state (() -> SearchResult state)
    | Ongoing state (() -> SearchResult state)


{-| Defines the type of the step function that produces new states from existing
    ones. This is how the graph over the search space is defined.
-}
type alias Step state =
    Node state -> List (Node state)


{-| Defines the type of a bundle of operators that need to be supplied to conduct
    an uninformed (non-heuristic) search.
-}
type alias Uninformed state =
    { step : Step state
    }


{-| Defines the operations needed on state buffers that hold the pending search
    states.
-}
type alias Buffer state buffer =
    { orelse : Node state -> buffer -> buffer
    , head : buffer -> Maybe ( Node state, buffer )
    , init : List (Node state) -> buffer
    }


{-| Performs an uninformed search.
-}
search : Buffer state buffer -> Uninformed state -> List (Node state) -> SearchResult state
search buffer uninformed start =
    let
        step =
            uninformed.step

        examineHead : buffer -> SearchResult state
        examineHead queue =
            let
                expand state queue =
                    (\() ->
                        examineHead <|
                            List.foldl (\node queue -> (buffer.orelse node queue)) queue (step ( state, False ))
                    )
            in
                case buffer.head queue of
                    Nothing ->
                        Complete

                    Just ( ( state, True ), pendingStates ) ->
                        Goal state (expand state pendingStates)

                    Just ( ( state, False ), pendingStates ) ->
                        Ongoing (Debug.log "search" state) (expand state pendingStates)
    in
        examineHead <| buffer.init start


{-| Implements a first-in first-out buffer using Lists.
-}
fifo : Buffer state (List (Node state))
fifo =
    { orelse = \node list -> node :: list
    , head =
        \list ->
            case list of
                [] ->
                    Nothing

                x :: xs ->
                    Just ( x, xs )
    , init = \list -> list
    }


{-| Implements a last-in first-out buffer using Lists and appending at to the end.
-}
lifo : Buffer state (List (Node state))
lifo =
    { fifo
        | orelse = \node list -> list ++ [ node ]
    }


{-| Performs an unbounded depth first search. Depth first searches can easily
    fall into infinite loops.
-}
depthFirstSearch : Uninformed state -> List (Node state) -> SearchResult state
depthFirstSearch =
    search fifo


{-| Performs an unbounded breadth first search. Breadth first searches store
    a lot of pending nodes in the buffer, so quickly run out of space.
-}
breadthFirstSearch : Uninformed state -> List (Node state) -> SearchResult state
breadthFirstSearch =
    search lifo


{-| Steps a search result, to produce the next result.
   * The result of this function may be an Ongoing search. This will provide the
     current head search node and a continuation to run the remainder of the search.
-}
next : SearchResult state -> SearchResult state
next result =
    case result of
        Complete ->
            Complete

        Goal state cont ->
            cont ()

        Ongoing _ cont ->
            cont ()


{-| Continues a search result, to produce the next search goal.
   * The result of this function will never be an Ongoing search. This
     function will recursively apply the search until either a Goal state if
     found or the walk over the search space is Complete.
-}
nextGoal : SearchResult state -> SearchResult state
nextGoal result =
    case result of
        Complete ->
            Complete

        Goal state cont ->
            Goal state cont

        Ongoing _ cont ->
            cont () |> nextGoal
