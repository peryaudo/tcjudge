# tcjudge: Judges TopCoder solutions locally

tcjudge is a simple command line tool that judges TopCoder solutions within local environment.

[日本語はこちら](https://github.com/peryaudo/tcjudge/blob/master/README.md)

## Features

* Creates scaffold files
* Executes faster than official
* Does not mess up your local directory
* Highly configurable through Ruby
* Supports multiple languages (C++, Java, C#, Haskell, Python) and compilers (GCC, clang, VC++, Mono, VC#, GHC)
* Score calculation

## Usage

If the name of a problem you want to solve is BallsConverter, you can create a scaffold file by

	tcjudge create BallsConverter.cpp

. Then you can run the judgement by

	tcjudge judge BallsConverter.cpp

or

	tcjudge BallsConverter.cpp

. tcjudge automatically detects the language by its extension.

Also, you can cut out from "CUT begin" to "CUT end" by

	tcjudge clean BallsConverter.cpp

. It emits the source code to stdout. It is especially useful when used like 

	tcjudge clean BallsConverter.cpp | pbcopy

## Prerequisites

* Ruby >= 1.9.3

## Installation

	gem install tcjudge

## Configuration

See .tcjudgerc file for detail. Defaults will be used if you don't create one.

You can use cl.exe for C++ compiler too.

## License

The MIT License (MIT)

Copyright (c) 2013-2015 peryaudo.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
