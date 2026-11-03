#!/usr/bin/env perl
# roundimg.pl - 画像の四隅を透明に切り抜いて角丸の PNG を作る
#
# 使い方:
#   perl roundimg.pl [-r 半径] [-w 最大幅] 画像ファイル...
#
#   -r 半径    角の半径(ピクセル、縮小後の画像に対して)。既定値 40
#   -w 最大幅  幅がこれより大きい画像は縮小してから角丸にする。既定値 0(縮小しない)
#
# 例:
#   perl roundimg.pl fo-01/images/photo1.jpg
#   perl roundimg.pl -r 24 -w 800 fo-01/images/*.jpg
#
# 出力: 入力と同じ場所に「元の名前-r.png」で保存する(photo1.jpg → photo1-r.png)
# 必要: ImageMagick(7 の magick を優先、無ければ 6 の convert)
#       FreeBSD: pkg install ImageMagick7-nox11

use strict;
use warnings;
use Getopt::Std;
use File::Basename;

my %opt;
getopts('r:w:', \%opt) or usage();
my $radius = defined $opt{r} ? $opt{r} : 40;
my $maxw   = defined $opt{w} ? $opt{w} : 0;
usage() unless @ARGV;
die "半径は 0 以上の整数で指定してください\n"   unless $radius =~ /^\d+$/;
die "最大幅は 0 以上の整数で指定してください\n" unless $maxw   =~ /^\d+$/;

# ImageMagick 7 の magick を優先し、無ければ 6 の convert を使う
my $im = (grep { -x "$_/magick" } split /:/, $ENV{PATH}) ? 'magick' : 'convert';

my $ng = 0;
for my $in (@ARGV) {
    unless (-f $in) {
        warn "見つかりません: $in\n";
        $ng++;
        next;
    }
    # 出力ファイル名: 拡張子を除いた名前に -r.png を付ける
    my ($name, $dir) = fileparse($in, qr/\.[^.]*/);
    my $out = "$dir$name-r.png";

    # 縮小指定がある場合、「幅が maxw より大きいときだけ縮小」(> の指定)
    my @resize = $maxw ? ('-resize', "${maxw}x>") : ();

    # 縮小後の幅と高さを取得する(マスクの大きさを合わせるため)
    # (シェルを介さないリスト形式で実行し、ファイル名の空白や記号に対応)
    my $size = '';
    if (open(my $fh, '-|', $im, $in, @resize, '-print', '%w %h', 'null:')) {
        local $/;
        $size = <$fh> // '';
        close($fh);
    }
    if ($size !~ /^(\d+) (\d+)/) {
        warn "画像サイズを取得できません: $in\n";
        $ng++;
        next;
    }
    my ($w, $h) = ($1, $2);

    # 半径が画像の半分を超えると形が崩れるので制限する
    my $r = $radius;
    my $lim = int(($w < $h ? $w : $h) / 2);
    $r = $lim if $r > $lim;

    # 角丸の白い四角形をマスクとして作り、写真の透明度に適用する
    # (リスト形式の system なので、ファイル名に空白があってもよい)
    my @cmd = (
        $im, $in, @resize,
        '(', '-size', "${w}x${h}", 'xc:none', '-fill', 'white',
             '-draw', sprintf('roundrectangle 0,0,%d,%d,%d,%d', $w - 1, $h - 1, $r, $r),
        ')',
        '-alpha', 'set', '-compose', 'DstIn', '-composite', $out,
    );
    if (system(@cmd) != 0) {
        warn "変換に失敗しました: $in\n";
        $ng++;
        next;
    }
    printf "%s -> %s (%dx%d, 半径 %d, %d KB)\n",
        $in, $out, $w, $h, $r, int((-s $out) / 1024);
}
exit($ng ? 1 : 0);

sub usage {
    die "使い方: perl roundimg.pl [-r 半径] [-w 最大幅] 画像ファイル...\n";
}
