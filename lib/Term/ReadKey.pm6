
module Term::ReadKey:ver<0.0.1> {
  use Term::termios;
  use NativeCall;

  sub getchar() returns int32 is native { * }

  sub with-termios(Callable:D $fn, Bool:D :$echo = True --> Str) {
    my $original-flags := Term::termios.new(:fd($*IN.native-descriptor)).getattr;
    my $flags := Term::termios.new(:fd($*IN.native-descriptor)).getattr;

    $flags.unset_lflags('ICANON');
    $flags.unset_lflags('ECHO') unless $echo;
    $flags.setattr(:NOW);

    my $result = $fn();

    $original-flags.setattr(:NOW);

    return $result;
  }

  sub read-character returns Str {
    my Buf $buf .= new;
    my Str $ch = Nil;

    loop {
      # Catch decoding errors and read more bytes until we have a
      # complete/valid UTF-8 sequence.
      CATCH { default { next } }

      $_ != -1 and $ch = $buf.append($_).decode with getchar;

      last;
    }

    return $ch;
  }

  sub read-key(Bool:D :$echo = True --> Str) is export {
    return with-termios(&read-character, :$echo);
  }

  sub key-pressed(Bool:D :$echo = True --> Supply) is export {
    my Supplier $supplier .= new;

    my $done = False;
    my $supply = $supplier.Supply.on-close: { $done = True };

    start {
      with-termios(
        sub {
          until $done {
            my $ch = read-character;

            last if $ch ~~ Nil;

            $supplier.emit($ch);
          }
        },
        :$echo
      );
    }

    return $supply;
  }
}

