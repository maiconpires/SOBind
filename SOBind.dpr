program SOBind;

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  System.StartUpCopy,
  FMX.Forms,
  sample.form in 'sample.form.pas' {Form1},
  SO.Binding_junto_e_misturado in 'SO.Binding_junto_e_misturado.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
