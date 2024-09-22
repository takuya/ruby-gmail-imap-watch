## Gmail IMAP サーバーに繋いで、Push通知をもらう。

IMAPにはIDLEコマンドが有り、IDLEコマンドで接続待ちをしてると、メール受信の通知を受け取ることができる。

このことから、GMailのIMAPにIDELコマンドで接続し、PUSHで通知をもらおうということである。

## Installing

## Example 
example run
`bundle exec ruby bin/imap-subscribe.rb`

sample usage
```ruby
# Load XOAUTH config 
Dotenv.load('.env', '.env.sample')
ENV['client_secret_path'] = File.realpath ENV['client_secret_path']
ENV['token_path'] = File.realpath ENV['token_path']
ENV['user_id'] = ENV['user_id'].strip
##
raise "Empty file (#{ENV['token_path']})." unless YAML.load_file(ENV['token_path'])
ENV['user_id'] = YAML.load_file(ENV['token_path']).keys[0] if ENV['user_id'].empty?

## enabling imap log
# ENV['DEBUG']='1'


watcher = Takuya::GmailIMAPWatcher.new

## add event handler 
watcher.on_message_received do |mail|
  # @type mail [Mail]
  puts " new message delivered."
  puts mail.message_id
end

## start listening
watcher.start

```

## IMAP#idle 

`IMAP#idle(timeout,&block)` は、排他的に動く。サーバーからのTCP受信を待ち受ける（PUSH通知）

`idle_done` は idle block 内部で行う必要がある。

idle_done すると idle は停止するが、TCP受信処理は行われる。（⇐ここがややこしい）

例えば、３つのFETCH が来たとき(３つ同時に既読フラグを付けた場合)

```text
+ idling
* 2 FETCH (UID 216 FLAGS (\Seen))
* 3 FETCH (UID 217 FLAGS (\Seen))
* 5 FETCH (UID 218 FLAGS (\Seen))
```

idle_done は 最初の uid 216 で呼び出される。しかし、連続でTCP受信している。
idle_done は実行待ちになる。 ３つのFETCHがそれぞれidle_doneを呼び出し、最初 idle_done が優先されるような動作になる。

そのため、次のようなコードは、３つのFETCHのうち、どのresponseを見ているのだろうか。見失うことになる。

```ruby
imap.idle(300) do | res |
  if res.kind_of?(Net::IMAP::UntaggedResponse) && res.name == 'FETCH'
    # uid=216 で done されるので、uid=217,uid=218はココまで来ない。ただしTCP受信と保存はしてる。
    uid = res.attr["UID"]
    imap.idle_done
  end
end
## でも受信はしてる
imap.responses["FETCH"].size # => 3
imap.responses["FETCH"].map{|e|e.attr["UID"]} #=> [216,217,218] 
```

なので、次のように、idle_doneを終えてからデータを取り出す必要がある。

```ruby
loop do
  last_response = nil
  imap.idle(300) do |res|
    if res.kind_of?(Net::IMAP::UntaggedResponse) && res.name=='FETCH'
      last_response = res
      imap.idle_done
    end
  end

  ## after idle_done
  if last_response.kind_of?(Net::IMAP::UntaggedResponse)
    case last_response.name
      when 'FETCH'
        imap.responses["FETCH"]
    end
  end
end

```

IMAPをスレッドで扱えるようなことがマニュアルに書いてあるが、idle中は動作不良なので注意

IMAPのidle中はTCP（OpenSSL）のコネクションを占拠する。
IMAP#idle_doneの実装をつかうと、コード複雑になりがち。 idleとidle_doneの実装は問題が多い。

IMAPコネクションを複数使ったほうがマシかもれない。
IDLE専用のコネクションと検索コネクションで別個にIMAPをインスタンス化するほうがスッキリかける。

このレポジトリでは其のような書き方はしていない。

変わりに、ミュータブルオブジェクトを使ってメソッドの実装箇所を分けた。

```ruby

def callback_generator(mutable_object)
  lambda do |res|
    if res.kind_of?(Net::IMAP::UntaggedResponse) && res.name=='FETCH'
      mutable_object.body = res
      imap.idle_done
    end
  end
end

loop do
  mutable_object = Struct.new(:body).new
  imap.idle(300, &( callback_generator mutable_object) )
  ## after idle_done
  if mutable_object.body.kind_of?(Net::IMAP::UntaggedResponse)
    case mutable_object.body.name
      when 'FETCH'
        imap.responses["FETCH"]
    end
  end
end

```

`lambda`と`Proc.new` には例外キャッチや変数束縛に違いがあるので注意すること。

特に、IMAP.idleはスレッド動作だからProc.newでは例外キャッチができないので注意。

## IMAP EXPUNGE, EXISTS

GMail IMAP で EXPUNGE でメールが「ゴミ箱」「アーカイブ」された場合はuidが変わるので追跡できない。

IMAPはメールボックスごとにUIDが作られるので、ボックスを移動したらUIDは変化する。

また、idle時にメールを削除（移動）したとき、EXPUNGEとEXISTSがペアで通知されてくる。

## IMAP#select IMAP#examine 

GmailをIMAPでメールを読み出すとき、自動的に既読になる。
```ruby
imap.select("INBOX")
envelope = imap.uid_fetch(uid, 'RFC822')[0].attr['RFC822'] # ここで既読になる。
```

メールボックスの開き方には２種類ある。

```ruby
imap.select("INBOX")
imap.examine("INBOX")
```

examineはREADONLYである。リードオンリーだと既読フラグがつかない。

SELECTは便利だけど、同期的に操作される。なので「メール本文」を読み込むと既読になる。

メール本文の開き方（既読をつけずに取得）

```ruby
# 既読がつく
envelope = imap.uid_fetch(uid, 'RFC822')[0].attr['RFC822']
# 影響なし
envelope = imap.uid_fetch(uid, "BODY.PEEK[]")[0].attr['BODY[]'] 
```


RFC822で開くとき、`select`だと容赦なく既読 `read(:seen)`　にされる。 `examine` の場合は変更されない。 不安定なので、`BODY.PEEK[]`を使うべき


まとめると、次のようになる。


|fetch/mbox| select | examine |
|:---:|:---:|:---:|
|RFC822|**既読**|無変|
|BODY.PEEK|無変|無変|


select で開かない限り、既読がつくことはない。

- 自動化プログラムから扱うときは基本的に examineで行う。
- メールアプリなどユーザー操作と連動するときは selectをつかう。

