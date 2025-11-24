unit sample.form;

interface

uses
  System.SysUtils, System.Classes, System.Types,
  FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.Controls, FMX.ListBox,
  FMX.Objects, FMX.DateTimeCtrls, FMX.Types, FMX.Controls.Presentation,
  SO.Binding_junto_e_misturado, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  FMX.Dialogs, FMX.Graphics, FMX.Layouts;

type
  TPessoa = class
  private
    FNome: string;
    FAtivo: Boolean;
    FIdade: Integer;
    FDataNasc: TDate;
    FFotoPath: string;
    FUf: String;
    FFotoBitmap: TBitmap;
    FFotoBase64: String;

  public
    constructor Create;
    destructor Destroy; override;

    property Nome: string read FNome write FNome;
    property Ativo: Boolean read FAtivo write FAtivo;
    property Idade: Integer read FIdade write FIdade;
    property DataNasc: TDate read FDataNasc write FDataNasc;
    property FotoPath: string read FFotoPath write FFotoPath;
    property FotoBitmap: TBitmap read FFotoBitmap write FFotoBitmap;
    property FotoBase64: String read FFotoBase64 write FFotoBase64;
    property UF: String read FUf write FUf;
  end;

  TForm1 = class(TForm)
    ImageFoto1: TImage;
    BtnTestarObjToUI: TButton;
    btnDebug: TButton;
    Memo1: TMemo;
    btnImageFile: TButton;
    OpenDialog1: TOpenDialog;
    ImageFoto2: TImage;
    ImageFoto3: TImage;
    btnImageBase64: TButton;
    Button3: TButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Layout1: TLayout;
    CheckAtivo: TCheckBox;
    Label3: TLabel;
    detNascimento: TDateEdit;
    CmbEstado: TComboBox;
    lblIdade: TLabel;
    tkbIdade: TTrackBar;
    Label2: TLabel;
    edtNome: TEdit;
    Label1: TLabel;
    Layout2: TLayout;
    btnChangeObject: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BtnTestarObjToUIClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnDebugClick(Sender: TObject);
    procedure btnImageFileClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure btnImageBase64Click(Sender: TObject);
    procedure btnChangeObjectClick(Sender: TObject);
  private
    procedure PopularEstados;
  end;

var
  Form1: TForm1;

  Binder: TSOBinder;
  Pessoa: TPessoa;


implementation

{$R *.fmx}

procedure TForm1.btnChangeObjectClick(Sender: TObject);
begin
  Pessoa.Nome := 'Fulano';
  Pessoa.Ativo := True;
  Pessoa.Idade := 30;
  Pessoa.DataNasc := EncodeDate(1994, 5, 15);
  Pessoa.UF := 'MG';

end;

procedure TForm1.btnDebugClick(Sender: TObject);
begin
  Memo1.Lines.Clear;

  Memo1.Lines.Add('Nome: '+Pessoa.Nome);
  Memo1.Lines.Add('Ativo: '+Pessoa.Ativo.ToString);
  Memo1.Lines.Add('Idade: '+Pessoa.Idade.ToString);
  Memo1.Lines.Add('DataNasc: '+DateToStr(Pessoa.DataNasc));
  Memo1.Lines.Add('UF: '+Pessoa.UF);
  Memo1.Lines.Add('Foto: '+Pessoa.FotoPath);
  Memo1.Lines.Add('FotoBase64: '+Pessoa.FotoBase64);
  Memo1.Lines.Add('FotoBitmap: '+Pessoa.FotoBitmap.ToString);
end;

procedure TForm1.btnImageFileClick(Sender: TObject);
begin
  if OpenDialog1.Execute then begin
    Pessoa.FotoPath := OpenDialog1.FileName;
  end;
end;

procedure TForm1.btnImageBase64Click(Sender: TObject);
begin
  Pessoa.FotoBase64 :=
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAApgAAAKYB3X3/'+
    'OAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAANCSURBVEiJtZZPbBtFFMZ/M7ubXdtdb1xSFyei'+
    'lBapySVU8h8OoFaooFSqiihIVIpQBKci6KEg9Q6H9kovIHoCIVQJJCKE1ENFjnAgcaSGC6rEnxBwA04Tx43t2FnvDAfj'+
    'kNibxgHxnWb2e/u992bee7tCa00YFsffekFY+nUzFtjW0LrvjRXrCDIAaPLlW0nHL0SsZtVoaF98mLrx3pdhOqLtYPHC'+
    'hahZcYYO7KvPFxvRl5XPp1sN3adWiD1ZAqD6XYK1b/dvE5IWryTt2udLFedwc1+9kLp+vbbpoDh+6TklxBeAi9TL0tae'+
    'WpdmZzQDry0AcO+jQ12RyohqqoYoo8RDwJrU+qXkjWtfi8Xxt58BdQuwQs9qC/afLwCw8tnQbqYAPsgxE1S6F3EAIXux'+
    '2oQFKm0ihMsOF71dHYx+f3NND68ghCu1YIoePPQN1pGRABkJ6Bus96CutRZMydTl+TvuiRW1m3n0eDl0vRPcEysqdXn+'+
    'jsQPsrHMquGeXEaY4Yk4wxWcY5V/9scqOMOVUFthatyTy8QyqwZ+kDURKoMWxNKr2EeqVKcTNOajqKoBgOE28U4tdQl5'+
    'p5bwCw7BWquaZSzAPlwjlithJtp3pTImSqQRrb2Z8PHGigD4RZuNX6JYj6wj7O4TFLbCO/Mn/m8R+h6rYSUb3ekokRY6'+
    'f/YukArN979jcW+V/S8g0eT/N3VN3kTqWbQ428m9/8k0P/1aIhF36PccEl6EhOcAUCrXKZXXWS3XKd2vc/TRBG9O5ELC'+
    '17MmWubD2nKhUKZa26Ba2+D3P+4/MNCFwg59oWVeYhkzgN/JDR8deKBoD7Y+ljEjGZ0sosXVTvbc6RHirr2reNy1OXd6'+
    'pJsQ+gqjk8VWFYmHrwBzW/n+uMPFiRwHB2I7ih8ciHFxIkd/3Omk5tCDV1t+2nNu5sxxpDFNx+huNhVT3/zMDz8usXC3'+
    'ddaHBj1GHj/As08fwTS7Kt1HBTmyN29vdwAw+/wbwLVOJ3uAD1wi/dUH7Qei66PfyuRj4Ik9is+hglfbkbfR3cnZm7ch'+
    'lUWLdwmprtCohX4HUtlOcQjLYCu+fzGJH2QRKvP3UNz8bWk1qMxjGTOMThZ3kvgLI5AzFfo379UAAAAASUVORK5CYII=';
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    if OpenDialog1.Execute then begin
      Bmp.LoadFromFile(OpenDialog1.FileName);
      Pessoa.FotoBitmap.Assign(Bmp);

      Binder.RefreshAll;
    end;
  finally
    Bmp.Free;
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pessoa := TPessoa.Create;
  PopularEstados;

  Binder := TSOBinder.Create;

  // Bindings
  Binder.BindTwoWay(edtNome, Pessoa, 'Nome', TTextAdapter.Create);
  Binder.BindTwoWay(CheckAtivo, Pessoa, 'Ativo', TBoolAdapter.Create);
  Binder.BindTwoWay(tkbIdade, Pessoa, 'Idade', TTrackBarAdapter.Create);
  Binder.BindTwoWay(detNascimento, Pessoa, 'DataNasc', TDateTimeAdapter.Create);
//  Binder.BindTwoWay(CmbEstado, Pessoa, 'uf', TListIndexAdapter.Create);
  Binder.BindTwoWay(CmbEstado, Pessoa, 'uf', TListTextAdapter.Create);

  // Label só mostra (One Way)
  Binder.BindOneWay(ImageFoto1, Pessoa, 'FotoPath', TImageAdapter.Create);
  Binder.BindOneWay(ImageFoto2, Pessoa, 'FotoBase64', TImageAdapter.Create);
  Binder.BindOneWay(ImageFoto3, Pessoa, 'FotoBitmap', TImageAdapter.Create);
  Binder.BindOneWay(lblIdade, Pessoa, 'idade', TLabelAdapter.Create);
 end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Binder.Free;
  Pessoa.Free;
end;

procedure TForm1.PopularEstados;
begin
  CmbEstado.Items.Add('SP');
  CmbEstado.Items.Add('RJ');
  CmbEstado.Items.Add('MG');
  CmbEstado.Items.Add('RS');
end;

procedure TForm1.BtnTestarObjToUIClick(Sender: TObject);
begin
  Binder.RefreshAll; // atualiza os controles
end;

{ TPessoa }

constructor TPessoa.Create;
begin
  FFotoBitmap := TBitmap.create;
end;

destructor TPessoa.Destroy;
begin
  if FFotoBitmap <> nil then
    FFotoBitmap.Free;

  inherited;
end;

end.
