# ObjectifiedEnvironments

Vastly improve maintainability of your Rails.env-dependent code by using object-oriented environments. Supports Rails 3.x and 4.x, running on Ruby 1.8.7 (3.x only), 1.9.2, 1.9.3, 2.0.0, and JRuby 1.7.4.

Current build status: ![Current Build Status](https://api.travis-ci.org/ageweke/objectified_environments.png?branch=master)

## What? Why?

Before:

    class UsersController < ApplicationController
      def create_user_from_remote
        ...

        timeout = case Rails.env
        when 'development' then 10
        when 'test' then 300
        when 'qa', 'beta' then 30
        else 5
        end

        Timeout::timeout(timeout) {
          ...
        }

        ...
      end
    end

After:

    class UsersController < ApplicationController
      def create_user_from_remote
        ...
        Timeout::timeout(Rails.objenv.timeout_for_create_user_from_remote) {
          ...
        }
        ...
      end
    end

You get:

* Elegant encapsulation of environment settings: they're just methods on a class that you define.
* All the power of Ruby to define those settings: inheritance, encapsulation, modules, delegation, and anything else you want.
* Utter [DRYness](http://en.wikipedia.org/wiki/Don't_repeat_yourself) of your environment code: if the `production` and `qa` environments are *almost* the same, you have a single superclass that defines all the ways in which they're the same &mdash; and the `Production` and `Qa` subclasses override only the things that vary in those environments. (Want to know why QA is behaving differently from production? Just open up its environment file!)
* Trivial maintenance of developer- or host-specific settings: if your login name is `joe`, create an environment `users/joe_development.rb` that subclasses `development.rb`, and override only what you want changed. And **check it in**. Now your fellow developers can refactor your changes along with everything else &mdash; and know why your machine behaves differently from everyone else's.
* Easy creation of new environments: inherit from (or factor out a common superclass from) the environment that is most like your new one, and then override only what you need.
* Wonderful behavior if you forget a setting: depending on the superclass, you'll get a reasonable default or a blindingly-obvious message about what you need to set, rather than an unintended and possibly-awful fallback.

## Wait, what? Really, why?

In large Ruby systems, there is inevitably a *lot* of behavior that is environment-dependent &mdash; cache sizes,
API keys, timeouts, debugging information, and so on. Rails' default environment mechanism does not accommodate
such large projects particularly well, and often big maintenance headaches ensue.

### The Theory

The way you are supposed to manage this is to create configuration points throughout your code, and set them in
the environment files in `config/environments`:

    class UsersController
      cattr_accessor :timeout_for_create_user_from_remote

      def create_user_from_remote
        Timeout::timeout(timeout_for_create_user_from_remote) {
          ...
        }
      end
    end

And then, for example, in `config/environments`:

    development.rb:
      ...
      UsersController.timeout_for_create_user_from_remote = 10
      ...
    test.rb:
      ...
      UsersController.timeout_for_create_user_from_remote = 300
      ...
    qa.rb:
      ...
      UsersController.timeout_for_create_user_from_remote = 30
      ...
    beta.rb:
      ...
      UsersController.timeout_for_create_user_from_remote = 30
      ...
    production.rb:
      ...
      UsersController.timeout_for_create_user_from_remote = 5
      ...

This does work. However, as you create more environments, you end up with more and more files that are almost always
copy-and-pasted from each other, suffering many of the problems that [Repeating Yourself](http://en.wikipedia.org/wiki/Don't_repeat_yourself) causes. Can you be certain that whoever creates a new environment has carefully thought through every single setting? Can you be certain that, when a developer creates a new setting, they have carefully added it to every environment file? And when someone needs to change a default, they have to go edit every single environment file and carefully think about it. (Is QA's timeout set to 5 for a good reason, or just because it was copy-and-pasted from production's?)

Compared to the above, using `objectified_environments` gives you significant improvements in maintainability, extension, and reliability.

### The Practice

In reality, unless your developers have incredible discipline, you very often end up with something different, like our first example above: code strewn all over your codebase, explicitly testing against `Rails.env`.

**This is a disaster**:

* When someone adds a new environment, they need to search *your entire codebase* for tests against `Rails.env` (or `RAILS_ENV`, or `ENV['RAILS_ENV']`), sit and think about every single one, figure out what the right value for the new environment is, and insert it.
* If someone misses a setting, then, depending on the exact syntax of the code in question (is there an `else` clause? does it use a default value, or raise an exception?), you might: get a reasonable value, get an exception that's clear, get an exception that's very unclear (maybe that variable just stays `nil`, and this causes problems far, far from the call site), or, worst of all, get silent failures that cause bad data in your database, bad pages or API results, or so on.
* Do you want to know how QA and production differ? Go search the entire codebase again, and think about each one.

When code is built in such a way that it naturally tends to cause problems, blaming developers (we're creative! we're wonderful! we're [lazy](http://threevirtues.com/)!) is the cheap way out. Let's build systems that make the easy way also the *right* way.

### The Solution

`objectified_environments` simply instantiates a class named after your `Rails.env` setting and binds it to `Rails.objenv`. You can then add methods to those classes, make them inherit from each other, override methods in subclasses, use delegation, modules, and any other tools that Ruby gives you to make them behave appropriately. The result is an easy-to-maintain, powerful environment system that makes it easy to add new environments, figure out the differences between environments, and so on.

## Installation

1. In any supported Rails environment, add this to your Gemfile, and then run `bundle install`:

        gem 'objectified_environments'

1. Run the generator:

        rails generate objectified_environments

1. This will generate a hierarchy of classes in `config/lib/objenv`, as so:

        ObjectifiedEnvironments::Base         # this is built-in to the Gem
          Objenv::Environment                 # 'Objenv::' prefix is required for your classes
            Objenv::LocalEnvironment
              Objenv::Development
              Objenv::Test
            Objenv::ProductionEnvironment
              Objenv::Production

1. If you have any environments beyond the standard three (`development`, `test`, and `production`) defined in `config/environments`, you'll also have classes defined for them. However, because the gem cannot know the proper superclass for them, they will all derive directly from the base `Objenv::Environment` class. Feel free to change this.

## Usage

The *only* change this makes in your system is that now `Rails.objenv` will automatically be a reference to an instance of whatever class is named the same as your environment (using Rails' camel-casing conventions) in the `Objenv::` namespace. This enables all the functionality above, but does not require any immediate changes.

As you introduce new features &mdash; or want to move existing ones to this system &mdash; simply add a method to one or more of these classes, and call it from your code via `Rails.objenv.my_method`. How you do this depends on the desired behavior of the code in question:

* **Reasonable default, needs to be overridden in some environments**: Add the method to `Objenv::Environment` returning the right value or doing the right thing. Override it in whatever subclasses need a different value.
* **No reasonable default, needs to be defined in all environments**: While you don't need to define the method on `Objenv::Environment`, doing so in such a way that raises an exception (the `ObjectifiedEnvironments::Base#must_implement` method will do this automatically for you) is a nice way to make it clear to other developers that they need to implement this method &mdash; and lets them instantly see what's going on if they forget to override it.

**The `LocalEnvironment` and `ProductionEnvironment` classes**: These classes are created by the generator for convenience' sake. Typically, the `development` and `test` environments have a lot in common. The generator sets up `Development` and `Test` to inherit from `LocalEnvironment` &mdash; so, if you put the code they have in common in `LocalEnvironment`, it will automatically be shared. And while Rails does not ship with a default `qa`, `beta`, or other such environment, these are incredibly common and almost always share a lot of code with `production`. Thus, `ProductionEnvironment` is created as a good place for this code.

Note that these are all simply suggestions; there is nothing more mysterious going on here than ordinary Ruby object-oriented structure. Do whatever works best for you. The generator sets up defaults that seem reasonable according to the author of this Gem, but the world is yours, and the Gem doesn't enforce any particular structure at all.

You may also wish to explore creating methods that actually do things, rather than simply returning configuration information. For example, having a method that returns the client object for Memcached can be very powerful, because now your environment can do anything it needs to do to set up that client &mdash; potentially returning a proxy for multiple servers, for example &mdash; rather than being restricted to only returning a single host and port.

### User- and Host-Specific Environments

Often, developers want to override certain environmental behavior on just machines they're logged into. Sometimes, we want to change environmental behavior on only particular hosts. Typically this is done via some (gross) combination of leaving environment files modified, adding a new 'local environment' file and calling it from the end of the master environment file, or even automating this with `patch`, `sed`, or some other such tool.

No matter what system is used to do this, it has significant drawbacks &mdash; one of the biggest of which is that these 'local changes' are almost never visible to other developers. If you've changed `MyController.user_cache_size` on your machine, and then someone else renames it to `MyController.people_cache_size`, then at best your next pull breaks your development environment in a very frustrating way &mdash; and at worst, your cache-size change is now forever silently ignored.

`objectified_environments` provides a better way. If you are logged in as user `acid_burn` on a machine called `the_gibson` with `Rails.env` set to `development`, then the Gem will assign to `Rails.objenv` the first class that exists from the following list:

    Objenv::UserHost::AcidBurnTheGibsonDevelopment
    Objenv::Host::TheGibsonDevelopment
    Objenv::User::AcidBurnDevelopment
    Objenv::Development

Thus, you can create `Objenv::User::AcidBurnDevelopment` as a subclass of `Objenv::Development`, override whatever settings you want, and *check it in*. Now, all other developers can see what you've overridden locally, cleanly change it for you if they're refactoring, and so on.

It is possible to tie yourself into insane knots by creating massive numbers of user-specific, host-specific, and (especially) user-and-host-specific overrides this way. We recommend keeping this extremely simple &mdash; but the power is there, if you need it.

### Relationship with `config/environments` files

Because Rails still loads files in `config/environments` for each environment, you will need to keep those files there and create them for any new environments you make, in addition to `Objenv::` classes &mdash; Rails really doesn't like not having one. (A patch that eliminates this requirement would be fantastic!)

Also, the configuration done in these files is *not* automatically subsumed by `objectified_environments`. If you wish (and it's highly recommended), you can move this code into the objectified environments, call it from the files in `config/environments`, and refactor it in any way you want. (The generator doesn't move this code automatically because the files in `config/environments` can contain any arbitrary Ruby code that's structured in any manner you want, and doing this safely borders on the impossible.)

### A Few Last Details:

* Once you install this gem, having an `Objenv::` class defined that matches your `Rails.env` setting is **mandatory**. This is required because otherwise we would have no idea what object to assign to `Rails.objenv`.
* The `Objenv::` namespace prefix requirement is so that environment names won't conflict with any classes of your own that you define with these names. (If you want to create a class called `Development` for other purposes, we don't want to stop you.)
* There is no requirement that your classes inherit from `ObjectifiedEnvironments::Base`; they can be any kind of Ruby object. They must be able to be instantiated with either no arguments, or one argument; if the constructor accepts an argument, it will be passed a hash containing `:rails_env`, `:user_name`, and `:host_name`. `ObjectifiedEnvironments::Base` stores this away and exposes it via *private* methods. (The fact that they're private is important; having you call `Rails.objenv.rails_env` subverts the entire system.)
* There is actually no requirement that your environment classes live under `config/lib`; this is merely a convention. As long as Rails is able to find them using its autoloading behavior, they will work just fine.
* `ObjectifiedEnvironments::Base` defines a nice `must_implement` method that simply raises an exception, saying you must implement a method. This is a nice thing to call in methods you define in `Environment` that have no reasonable default.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

While I thoroughly encourage any and all contributions, ideas, bug reports, bug fixes, and so on, I do request that you include full tests (specs) in your patch if you do contribute a patch back.

## License

This code is licensed under the terms in the accompanying `LICENSE` file.
