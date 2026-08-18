program ficwrite;

{$mode objfpc}{$H+}

uses
  SysUtils, doption, gdoc;

procedure PrintUsage;
begin
  WriteLn('Usage: ficwrite [options] filename');
end;

var
  Document : tDocument;
  index : integer;
  
begin
  ParseCommandLine;

  Document := tDocument.Create;
  if (Options.Filename <> '') then
    Document.LoadFromFile (Options.Filename);
    
  { Temporary diagnostic output. }
  WriteLn('Filename: ', Options.FileName);
  for index := 0 to (Document.ParagraphCount - 1) do
    writeln (Document.Paragraph [index].Text);

  { Editor will eventually start here. }
end.
