## Kanban (for simple rate-limiting)

*Disclaimer: I may never use github the way it is intended. I have plans to share gems and projects that may involve collaboration, but I suspect most of my "projects" will be little more than code showcases.*

### Abstract

Web services APIs usually have specified rate limits.

*Kanban* is a Japanese word that means "signboard". It is the name given to a just-in-time manufacturing or workflow management systems that limits work-in-progress via a card system (where cards are used to represent capacity or tasks).

A card system is how the Japanese might limit attendance in a park during hamami... For instance, one party receives a card upon entering a park, and when leaving, that card would be collected and given to another party, if the cards are strictly limited (and park-goers do not cheat), this ensures the park will never be filled beyond capacity.

Kanban workflow systems set card (or task) limits per work type and stage, in effect creating queuing systems for capacity management. After studying Kanban, and being confronted by API rate limits, I thought using kanban cards for rate-limiting might be a simple solution.

### Alternatives

This kanban solution includes polling, which should raise question of efficiency. Simplicity was given precedence over optimization. If this solution does not work in a performance-critical application, optimizations or another solution should be considered.

I considered a short list of alternatives (*sans* polling) when developing kanban rate-limiting...

- Redis sorted set with time-second scoring -- score querying is complex
- Redis database -- dedicated database with expiring keys could obviate polling
- Redis key counting -- regular expression query to avoid polling (seemingly foolish)
- MySQL table with task records

Approaching this again, I imagined another rate-limiting implementation. Given a limit of 50,000 calls per day, how could we avoid polling? We could keep track of the last card assigned, and always assign cards (from our pool of 50,000) in sequence. We would need to prevent race conditions. The polling solution preserves capacity (such that *waiting* is an option), whereas assigning cards in sequence could exhaust capacity quickly. Assigning slots in sequence allows us to know *when* capacity will be available, however, as we could check Redis time-to-live for the next card...

So this seems an interesting approach, perhaps slightly more complex, which might superior (taking into account service usage requirements).

### Implementation

*Limit* is the number of cards available during a given *period*. The values can be adjusted to match service rate limit, e.g. given a rate of 50,000 calls per day, we might use a limit of 32 (cards) and period of 60 (seconds).

When requested, if a card is available, take it (add expiring string to Redis) and return.

When no available card is found, we can either return false, or wait. If waiting for a card to be available, pause for *wait_delay* until checking again. *wait_limit* is used to avoid infinite waiting.

### Enhancements

I hope to create a gem implementing this solution.

Obvious improvements will be using Redis millisecond-based operations, adding different methods, passing parameters via hash, and handling parallel operation more robustly (detect and resolve clashes).

### Environment
When I was young and curious (thank you, David), I set up my system as suggested in *Agile Web Development with Rails*. No surprise, but I managed to get stuck following along with the book in the haze of Rails 3.0 ~> 3.1 ~> 3.2 progress. So I had to recover and start over using Homebrew and RVM to get this working sanely.

     ~ $ ruby --version
    ruby 1.9.3p194 (2012-04-20 revision 35410) [x86_64-darwin11.4.0]


### Example Code Run
     ~ $ ruby /Users/[...]/kanban/service.rb
    
    ~ Rate Limiting - Waiting for Kanban
    ~ 60 seconds - limit of 2 operations per 10 seconds
    2012-07-27 20:30:21.528
    2012-07-27 20:30:21.528
    2012-07-27 20:30:32.001
    2012-07-27 20:30:32.003
    2012-07-27 20:30:43.000
    2012-07-27 20:30:43.001
    2012-07-27 20:30:54.000
    2012-07-27 20:30:54.001
    2012-07-27 20:31:05.001
    2012-07-27 20:31:05.002
    2012-07-27 20:31:16.000
    2012-07-27 20:31:16.001
    2012-07-27 20:31:27.000
    
    ~ Rate Limiting - Dropping Tasks (Do Not Wait for Kanban)
    ~ 60 seconds - limit of 2 operations per 10 seconds
    2012-07-27 20:31:27.001
    2012-07-27 20:31:27.002
      [25636 requests skipped]
    2012-07-27 20:31:38.000
    2012-07-27 20:31:38.000
      [27462 requests skipped]
    2012-07-27 20:31:49.000
    2012-07-27 20:31:49.000
      [27319 requests skipped]
    2012-07-27 20:32:00.000
    2012-07-27 20:32:00.001
      [26077 requests skipped]
    2012-07-27 20:32:11.000
    2012-07-27 20:32:11.001
      [26496 requests skipped]
    2012-07-27 20:32:22.000
    2012-07-27 20:32:22.001


### Example Test Run
     ~ $ ruby /Users/[...]/kanban/service_test.rb
    Run options: --seed 49028
    
    # Running tests:
    
    ..
    
    Finished tests in 21.627030s, 0.0925 tests/s, 0.0925 assertions/s.
    
    2 tests, 2 assertions, 0 failures, 0 errors, 0 skips
