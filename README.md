# StreamComprehension
StreamComprehension allows for comprehensions to build streams instead of lists.

Sometimes when working with streams I find myself longing for the versatility of list
comprehensions. This project is an attempt to have the best of both worlds (for fun; no intent to
use this in production).

## Usage
You should be able to use stream comprehensions the same as regular comprehensions (less the `:into`
and `:reduce` options because that defeats the point), but the output will be a stream instead of a
list.

```elixir
import StreamComprehension

input = Stream.cycle([ok: "twenty-three", error: "forty-two", ok: "nineteen"])

my_stream =
             # only use words from :ok tuples
  stream for {:ok, word} <- input,
             # for demonstration purposes only; always truthy
             send(self(), {:word, word}),
             # show off bitstring generator
             <<character <- word>>,
             # filter on character being in lowercase alphabet
             character in ?a..?z do
    character
  end
#=> #Function<59.58486609/2 in Stream.transform/3>

flush()
#=> :ok

Enum.take(my_stream, 38)
#=> 'twentythreenineteentwentythreenineteen'

flush()
# {:word, "twenty-three"}
# {:word, "nineteen"}
# {:word, "twenty-three"}
# {:word, "nineteen"}
#=> :ok
```
