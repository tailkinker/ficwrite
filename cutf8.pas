unit cutf8;

{$mode objfpc}{$H+}

interface

function EncodeUTF8(const CodePoint: Cardinal): RawByteString;
function DecodeUTF8(const S: RawByteString; const BytePos: SizeInt; out CodePoint: Cardinal; out ByteLength: SizeInt): Boolean;

implementation

function EncodeUTF8(const CodePoint: Cardinal): RawByteString;
begin
  Result := '';
  if CodePoint <= $7F then begin
    SetLength(Result, 1);
    Result[1] := AnsiChar(CodePoint);
  end else if CodePoint <= $7FF then begin
    SetLength(Result, 2);
    Result[1] := AnsiChar($C0 or (CodePoint shr 6));
    Result[2] := AnsiChar($80 or (CodePoint and $3F));
  end else if CodePoint <= $FFFF then begin
    SetLength(Result, 3);
    Result[1] := AnsiChar($E0 or (CodePoint shr 12));
    Result[2] := AnsiChar(
      $80 or ((CodePoint shr 6) and $3F));
    Result[3] := AnsiChar(
      $80 or (CodePoint and $3F));
  end else if CodePoint <= $10FFFF then begin
    SetLength(Result, 4);
    Result[1] := AnsiChar($F0 or (CodePoint shr 18));
    Result[2] := AnsiChar(
      $80 or ((CodePoint shr 12) and $3F));
    Result[3] := AnsiChar(
      $80 or ((CodePoint shr 6) and $3F));
    Result[4] := AnsiChar(
      $80 or (CodePoint and $3F));
  end else
    Result := '';
end;

function DecodeUTF8(const S: RawByteString; const BytePos: SizeInt; out CodePoint: Cardinal; out ByteLength: SizeInt): Boolean;
var
  B1, B2, B3, B4: Byte;
begin
  Result := False;
  CodePoint := 0;
  ByteLength := 0;

  if (BytePos < 1) or (BytePos > System.Length(S)) then
    Exit;

  B1 := Ord(S[BytePos]);

  { ASCII: U+0000..U+007F }
  if B1 <= $7F then begin
    CodePoint := B1;
    ByteLength := 1;
    Result := True;
    Exit;
  end;

  { 2-byte sequence: U+0080..U+07FF }
  if (B1 >= $C2) and (B1 <= $DF) then begin
    if BytePos + 1 > System.Length(S) then
      Exit;

    B2 := Ord(S[BytePos + 1]);

    if (B2 and $C0) <> $80 then
      Exit;

    CodePoint :=
      (Cardinal(B1 and $1F) shl 6) or
      Cardinal(B2 and $3F);

    ByteLength := 2;
    Result := True;
    Exit;
  end;

  { 3-byte sequence: U+0800..U+FFFF,
    excluding UTF-16 surrogate code points. }
  if (B1 >= $E0) and (B1 <= $EF) then begin
    if BytePos + 2 > System.Length(S) then
      Exit;

    B2 := Ord(S[BytePos + 1]);
    B3 := Ord(S[BytePos + 2]);

    if ((B2 and $C0) <> $80) or
       ((B3 and $C0) <> $80) then
      Exit;

    { E0 80..9F would be an overlong encoding. }
    if (B1 = $E0) and (B2 < $A0) then
      Exit;

    { ED A0..BF would encode UTF-16 surrogates. }
    if (B1 = $ED) and (B2 >= $A0) then
      Exit;

    CodePoint :=
      (Cardinal(B1 and $0F) shl 12) or
      (Cardinal(B2 and $3F) shl 6) or
      Cardinal(B3 and $3F);

    ByteLength := 3;
    Result := True;
    Exit;
  end;

  { 4-byte sequence: U+10000..U+10FFFF }
  if (B1 >= $F0) and (B1 <= $F4) then begin
    if BytePos + 3 > System.Length(S) then
      Exit;

    B2 := Ord(S[BytePos + 1]);
    B3 := Ord(S[BytePos + 2]);
    B4 := Ord(S[BytePos + 3]);

    if ((B2 and $C0) <> $80) or
       ((B3 and $C0) <> $80) or
       ((B4 and $C0) <> $80) then
      Exit;

    { F0 80..8F would be an overlong encoding. }
    if (B1 = $F0) and (B2 < $90) then
      Exit;

    { F4 90..BF would exceed U+10FFFF. }
    if (B1 = $F4) and (B2 > $8F) then
      Exit;

    CodePoint :=
      (Cardinal(B1 and $07) shl 18) or
      (Cardinal(B2 and $3F) shl 12) or
      (Cardinal(B3 and $3F) shl 6) or
      Cardinal(B4 and $3F);

    ByteLength := 4;
    Result := True;
    Exit;
  end;
end;

end.
