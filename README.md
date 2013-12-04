# TopCoderのローカルジャッジのご紹介 (Competitive Programming Advent Calendar Div2013 Day4)

（README兼）

これは[Competitive Programming Advent Calendar Div2013](http://partake.in/events/3a3bb090-1390-4b2a-b38b-4273bea4cc83) 4日目の記事です。

今の所、アルゴリズム的な意味に興味深い記事を書いてる人が多くてめげそうなのですがめげずに行きます…
アルゴリズムの話はないです…すいません…

オンラインで定期的に実施される、代表的なプログラミングコンテストとして、Codeforcesと並びにTopCoderという物があります。
皆さんご存知だと思いますが、TopCoderの特徴の1つとして、Web上ではなくArenaと呼ばれる独自のJava製アプリケーションを用いて競技を行うという点があります。
しかしながら、Arenaの独特の操作性はコマンドラインツールに比べると不便に感じる事もあり、また全般的に動作が重いため、継続的にPracticeとして問題を解き続けるに当ってストレスを感じてしまうことが多々あります。
特に僕は回線の悪い所（通学電車内とか）でPracticeを開くことが多く、全然開かない、勝手に接続が切れてArenaが閉じる等、こいつのせいでつらぽよが生えていました。
他方、TopCoderの問題はWeb上でも[公開されており](http://community.topcoder.com/tc?module=MatchList)過去に出題された問題文を閲覧するだけであれば、Arenaを使う必要はありません。

そこで、コマンドラインのみで完結し、ローカルで高速なジャッジを行う事のできるtcjudgeを使いましょう！！

## tcjudgeの特徴

tcjudgeは以下のような特徴があります:

- テンプレート作成機能
- 本家よりは高速なジャッジ（ただしOSX/Linuxで動かしたほうが速い…Windowsだと本家とそんなに差はない…）
- Rubyを用いた設定ファイルによる柔軟な設定
- 複数の言語（C++, Java, C#）とコンパイラ（GCC, Clang, Visual C++, Mono, Visual C#）に対応
- Arena同様の点数計算

（このtcjudgeは[過去にC++で書いた物](http://d.hatena.ne.jp/peryaudo/20111121/1321891386)を、先日完全にRubyで書きなおした物で、Ruby製になったので誰でも(自分含む)いじりやすくなりました。）

同様のスクリプトとしては、[AirSRM](https://github.com/kawakami-o3/AirSRM)などが挙げられますが、tcjudgeは、簡潔なコマンドラインオプションと、手元（カレントディレクトリ）を汚さない設計思想に特徴があります。

## インストール方法

一式のダウンロードは[こちら](https://github.com/peryaudo/tcjudge/archive/master.zip)からどうぞ。

分からない所とかあったら@peryaudoまで遠慮無く聞いて下さい。

### Windows

Rubyを要求してきて一見めんどくさそうに見えますが一瞬です。

Ruby 1.9.3以上が必要なので、まずRubyを[RubyInstallerから取ってきて](http://rubyinstaller.org/downloads/)入れます。一瞬です。（何も考えずに一番上のインストーラを入れれば幸せになれます。入れる時にPATHに追加のチェックを忘れずに）

次に、一式を展開したディレクトリ内で

	gem install bundler
	bundle

と打って、あとはPATHの通った１つのディレクトリにtcjudgeとtcjudge.batを放り込むだけです。一瞬です。
（放り込む先は、迷ったらRubyInstallerでRuby入れたディレクトリ（例: C:\Ruby200\bin）みたいな場所でもいいです）

### Mac OS X

Ruby 1.9.3以上が必要です。
Mavericksでなら多分いろいろ考えなくてよくて楽だと思います。
（Mountain Lionの人はrbenvとかrvmとかを使ってがんばってRuby 2.0.0を入れてください… ）

	gem install bundler

して、その後一式を展開したディレクトリ内で

	make install

と打つだけです。

### Linux
Linuxとかを使っている人はいろいろ詳しい人だと思うので細かい事は省きます。
OSXと大体同じだと思います。

## 設定

ユーザーディレクトリ直下に、.tcjudgercというファイルを作って書きます。
以下のような事が書けます。書かなければデフォルト項目が使われます。

	@user_name = 'TopCoderのユーザー名'
	@password = 'TopCoderのパスワード' #（書かなければ毎回聞いてくるようになる）
	@compiler = { :CXX => 'g++' }
	@template = { :CXX => Proc.new { <<TEMPLATE
	#include <vector>
	#include <iostream>

	...

	TEMPLATE
	, :Java => "..." } }

詳しい書き方は、.tcjudgercの見本を見て下さい。

ちゃんとパスを通していればですが、C++のコンパイラにはVisual C++（cl.exe）も使えます。

## 使い方

使い方は至って簡単です。

解きたい問題名がBallsConverterだとして、

	tcjudge create BallsConverter.cpp

で、テンプレートを作成できて、ソースのおいてあるディレクトリで

	tcjudge judge BallsConverter.cpp

ないしは

	tcjudge BallsConverter.cpp

で、ジャッジが走ります。拡張子を見て自動で言語を判定します。

あと、

	tcjudge clean BallsConverter.cpp

で、CUT begin〜CUT endまでを切り取ったソースを標準入出力に吐いてくれるので、例えばOSXなら

	tcjudge clean BallsConverter.cpp | pbcopy

とかやってお手軽にGreedの吐いたソースからブログに貼れる用ソースを作るツールとしても使えます。

## Pull RequestsやIssuesをお待ちしております

Rubyで人間にも読みやすい割と拡張性のあるソースになってますし、是非使ってバグを発見したり、気になる所があったら是非Pull RequestなりIssue入れるなりしてください…
誰も使ってくれないと悲しいです…

C#とJavaはあまりテストしてないのでバグが残ってるかもしれないです。

MLEやTLEは今の所実装されてないです…（誰かうまく実装して…）
