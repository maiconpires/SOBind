unit SO.Binding_junto_e_misturado;

interface

uses
  System.SysUtils, System.Classes, System.Rtti, System.Generics.Collections,
  System.Generics.Defaults, System.Types, System.Math,
  FMX.Types, FMX.Controls, FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.ListBox,
  FMX.Objects, FMX.Controls.Presentation, FMX.DateTimeCtrls, FMX.Graphics,
  FMX.Layouts, System.NetEncoding, System.IOUtils, System.TypInfo, System.UITypes;

type
  IBindAdapter = interface
    ['{5E58D0C0-3678-4E1F-9F19-9C6D42253FDB}']
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TBindMap = class
  public
    Control: TFmxObject;
    Obj: TObject;
    PropName: string;
    PropInfo: TRttiProperty;
    Adapter: IBindAdapter;
  end;

  TSOBinder = class
  private
    FRttiCtx: TRttiContext;
    FMaps: TObjectList<TBindMap>;
    FMapByControl: TDictionary<TFmxObject, TBindMap>;

    procedure ControlChanged(Sender: TObject);
    function FindMapByControl(AControl: TFmxObject): TBindMap;
    procedure HookControlEvent(AControl: TFmxObject);
    procedure UnhookControlEvent(AControl: TFmxObject);
    procedure DisableEventProp(AControl: TFmxObject; PropInfo: PPropInfo);
    procedure RestoreEventProp(AControl: TFmxObject; PropInfo: PPropInfo);
    function FindEventProp(AControl: TFmxObject; out PropInfo: PPropInfo): Boolean;
    procedure TrySetPropValue(AObj: TObject; AProp: TRttiProperty; const AValue: TValue);
    function TryConvertForProp(const AValue: TValue; APropType: TRttiType): TValue;
  public
    constructor Create;
    destructor Destroy; override;

    procedure BindTwoWay(AControl: TFmxObject; AObj: TObject; const AProp: string; AAdapter: IBindAdapter);
    procedure BindOneWay(AControl: TFmxObject; AObj: TObject; const AProp: string; AAdapter: IBindAdapter);

    procedure RefreshAll;
    procedure RefreshControl(AControl: TFmxObject);
    procedure Unbind(AControl: TFmxObject); // remove binding de um controle
  end;

  // Adapters
  TTextAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TMemoAdapter = class(TTextAdapter) end;

  TBoolAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TListIndexAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TListTextAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TTrackBarAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TDateTimeAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  TLabelAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  end;

  // Image adapter: aceita TBitmap, filename (string), base64 string.
  TImageAdapter = class(TInterfacedObject, IBindAdapter)
    function ControlToValue(Control: TFmxObject): TValue;
    procedure ValueToControl(Control: TFmxObject; const Value: TValue);
  private
    function StringIsBase64(const S: string): Boolean;
    function BitmapFromBase64(const S: string): TBitmap;
  end;

implementation

type
  TMethodHolder = class
  public
    OrigMethod: TMethod;
    PropName: string;
  end;

{ TSOBinder }

constructor TSOBinder.Create;
begin
  inherited Create;
  FRttiCtx := TRttiContext.Create;
  FMaps := TObjectList<TBindMap>.Create(True);
  FMapByControl := TDictionary<TFmxObject, TBindMap>.Create;
end;

destructor TSOBinder.Destroy;
var
  pair: TPair<TFmxObject, TBindMap>;
begin
  // restaura eventos antes de liberar
  for pair in FMapByControl do
    UnhookControlEvent(pair.Key);

  FMapByControl.Free;
  FMaps.Free;
  inherited;
end;

procedure TSOBinder.BindTwoWay(AControl: TFmxObject; AObj: TObject; const AProp: string; AAdapter: IBindAdapter);
var
  bm: TBindMap;
  rType: TRttiType;
  p: TRttiProperty;
begin
  if (AControl = nil) or (AObj = nil) then
    raise Exception.Create('Control ou Obj nulo em BindTwoWay');

  rType := FRttiCtx.GetType(AObj.ClassType);
  p := rType.GetProperty(AProp);
  if p = nil then
    raise Exception.CreateFmt('Propriedade %s não encontrada em %s', [AProp, AObj.ClassName]);

  bm := TBindMap.Create;
  bm.Control := AControl;
  bm.Obj := AObj;
  bm.PropName := AProp;
  bm.PropInfo := p;
  bm.Adapter := AAdapter;

  FMaps.Add(bm);
  FMapByControl.Add(AControl, bm);

  // Atualiza controle com valor inicial do objeto
  RefreshControl(AControl);

  // Hook do evento do controle (para TwoWay)
  HookControlEvent(AControl);
end;

procedure TSOBinder.BindOneWay(AControl: TFmxObject; AObj: TObject; const AProp: string; AAdapter: IBindAdapter);
var
  bm: TBindMap;
  rType: TRttiType;
  p: TRttiProperty;
begin
  if (AControl = nil) or (AObj = nil) then
    raise Exception.Create('Control ou Obj nulo em BindOneWay');

  rType := FRttiCtx.GetType(AObj.ClassType);
  p := rType.GetProperty(AProp);
  if p = nil then
    raise Exception.CreateFmt('Propriedade %s não encontrada em %s', [AProp, AObj.ClassName]);

  bm := TBindMap.Create;
  bm.Control := AControl;
  bm.Obj := AObj;
  bm.PropName := AProp;
  bm.PropInfo := p;
  bm.Adapter := AAdapter;

  FMaps.Add(bm);
  FMapByControl.Add(AControl, bm);

  // atualiza o controle com valor do objeto
  RefreshControl(AControl);
  // não hooka evento (one-way)
end;

procedure TSOBinder.Unbind(AControl: TFmxObject);
var
  bm: TBindMap;
begin
  if FMapByControl.TryGetValue(AControl, bm) then
  begin
    UnhookControlEvent(AControl);
    FMapByControl.Remove(AControl);
    FMaps.Remove(bm);
  end;
end;

procedure TSOBinder.RefreshAll;
var
  bm: TBindMap;
begin
  for bm in FMaps do
    RefreshControl(bm.Control);
end;

procedure TSOBinder.RefreshControl(AControl: TFmxObject);
var
  bm: TBindMap;
  val: TValue;
begin
  bm := FindMapByControl(AControl);
  if bm = nil then Exit;

  val := bm.PropInfo.GetValue(bm.Obj);
  bm.Adapter.ValueToControl(bm.Control, val);
end;

function TSOBinder.FindMapByControl(AControl: TFmxObject): TBindMap;
begin
  if not FMapByControl.TryGetValue(AControl, Result) then
    Result := nil;
end;

procedure TSOBinder.ControlChanged(Sender: TObject);
var
  ctrl: TFmxObject;
  bm: TBindMap;
  val: TValue;
begin
  if not (Sender is TFmxObject) then Exit;
  ctrl := TFmxObject(Sender);
  bm := FindMapByControl(ctrl);
  if bm = nil then Exit;

  try
    val := bm.Adapter.ControlToValue(bm.Control);
    TrySetPropValue(bm.Obj, bm.PropInfo, val);
  except
    // swallow — opcional: log
  end;
end;

function TSOBinder.FindEventProp(AControl: TFmxObject; out PropInfo: PPropInfo): Boolean;
begin
  PropInfo := GetPropInfo(AControl.ClassInfo, 'OnChange');
  if PropInfo <> nil then Exit(True);

  PropInfo := GetPropInfo(AControl.ClassInfo, 'OnChangeTracking');
  if PropInfo <> nil then Exit(True);

  PropInfo := GetPropInfo(AControl.ClassInfo, 'OnClick');
  if PropInfo <> nil then Exit(True);

  PropInfo := GetPropInfo(AControl.ClassInfo, 'OnValueChange');
  if PropInfo <> nil then Exit(True);

  PropInfo := nil;
  Result := False;
end;

procedure TSOBinder.HookControlEvent(AControl: TFmxObject);
var
  propInfo: PPropInfo;
  m: TMethod;
begin
  if not FindEventProp(AControl, propInfo) then Exit;

  // Save original and set our handler
  DisableEventProp(AControl, propInfo);

  // assign our method as event: Data = Self, Code = method address
  m.Data := Self;
  m.Code := @TSOBinder.ControlChanged;
  try
    SetMethodProp(AControl, propInfo, m);
  except
    // ignore if cannot set
  end;
end;

procedure TSOBinder.UnhookControlEvent(AControl: TFmxObject);
var
  propInfo: PPropInfo;
begin
  if not FindEventProp(AControl, propInfo) then Exit;
  RestoreEventProp(AControl, propInfo);
end;

procedure TSOBinder.DisableEventProp(AControl: TFmxObject; PropInfo: PPropInfo);
var
  holder: TMethodHolder;
  origMethod: TMethod;
  nilMethod: TMethod;
begin
  if (AControl.TagObject is TMethodHolder) then
    holder := TMethodHolder(AControl.TagObject)
  else
  begin
    holder := TMethodHolder.Create;
    AControl.TagObject := holder;
  end;

  holder.PropName := PropInfo^.Name;

  // get original method (may be nil)
  try
    origMethod := GetMethodProp(AControl, PropInfo);
    holder.OrigMethod := origMethod;
  except
    holder.OrigMethod.Data := nil;
    holder.OrigMethod.Code := nil;
  end;

  // set nil to stop firing while we update programmatically
  nilMethod.Data := nil;
  nilMethod.Code := nil;
  try
    SetMethodProp(AControl, PropInfo, nilMethod);
  except
    // ignore
  end;
end;

procedure TSOBinder.RestoreEventProp(AControl: TFmxObject; PropInfo: PPropInfo);
var
  holder: TMethodHolder;
begin
  if not (AControl.TagObject is TMethodHolder) then Exit;
  holder := TMethodHolder(AControl.TagObject);

  try
    // restore original method (even if nil)
    SetMethodProp(AControl, PropInfo, holder.OrigMethod);
  except
    // ignore
  end;

  holder.Free;
  AControl.TagObject := nil;
end;

procedure TSOBinder.TrySetPropValue(AObj: TObject; AProp: TRttiProperty; const AValue: TValue);
var
  converted: TValue;
begin
  converted := TryConvertForProp(AValue, AProp.PropertyType);
  if not converted.IsEmpty then
  begin
    try
      AProp.SetValue(AObj, converted);
    except
      // swallow; se quiser, logar
    end;
  end;
end;

function TSOBinder.TryConvertForProp(const AValue: TValue; APropType: TRttiType): TValue;
begin
  Result := TValue.Empty;
  if AValue.IsEmpty then Exit;

  // 1) objeto / classe
  if (APropType is TRttiInstanceType) and (AValue.Kind = tkClass) then
  begin
    var instType := TRttiInstanceType(APropType);
    var obj := AValue.AsObject;
    if (obj <> nil) and obj.ClassType.InheritsFrom(instType.MetaclassType) then
    begin
      Result := AValue;
      Exit;
    end;
  end;

  // 2) string-like
  if APropType.TypeKind in [tkUString, tkLString, tkWString, tkString] then
  begin
    Result := TValue.From<string>(AValue.ToString);
    Exit;
  end;

  // 3) integer / enum
  if APropType.TypeKind in [tkInteger, tkInt64] then
  begin
    var intVal: Integer;
    if AValue.TryAsType<Integer>(intVal) then
      Result := TValue.From<Integer>(intVal)
    else if AValue.IsType<string> then
      Result := TValue.From<Integer>(StrToIntDef(AValue.AsString, 0))
    else if AValue.IsType<Double> then
      Result := TValue.From<Integer>(Trunc(AValue.AsExtended))
    else
      Result := TValue.Empty;
    Exit;
  end;

  // 4) float / double
  if APropType.TypeKind = tkFloat then
  begin
    var dblVal: Double;
    if AValue.TryAsType<Double>(dblVal) then
      Result := TValue.From<Double>(dblVal)
    else if AValue.IsType<string> then
      Result := TValue.From<Double>(StrToFloatDef(AValue.AsString, 0))
    else if AValue.IsType<Integer> then
      Result := TValue.From<Double>(AValue.AsInteger)
    else
      Result := TValue.Empty;
    Exit;
  end;

  // 5) boolean
  if SameText(APropType.QualifiedName, 'System.Boolean') then
  begin
    var bVal: Boolean;
    if AValue.TryAsType<Boolean>(bVal) then
      Result := TValue.From<Boolean>(bVal)
    else if AValue.IsType<string> then
      Result := TValue.From<Boolean>(SameText(AValue.AsString, 'true') or (AValue.AsString = '1'))
    else
      Result := TValue.Empty;
    Exit;
  end;

  // 6) TDateTime
  if SameText(APropType.QualifiedName, 'System.TDateTime') then
  begin
    var dtVal: TDateTime;
    if AValue.TryAsType<TDateTime>(dtVal) then
      Result := TValue.From<TDateTime>(dtVal)
    else if AValue.IsType<string> then
      Result := TValue.From<TDateTime>(StrToDateTimeDef(AValue.AsString, 0))
    else
      Result := TValue.Empty;
    Exit;
  end;

  // fallback
  Result := TValue.Empty;
end;

{ Adapters implementation }

{ TTextAdapter }
function TTextAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TEdit then
    Exit(TEdit(Control).Text);

  if Control is TMemo then
    Exit(TMemo(Control).Text);

  if Control is TPresentedTextControl then
    Exit(TPresentedTextControl(Control).Text);

  if Control is TLabel then
    Exit(TLabel(Control).Text);

  raise Exception.Create('TTextAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TTextAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
begin
  if Control is TEdit then
    TEdit(Control).Text := Value.ToString
  else if Control is TMemo then
    TMemo(Control).Text := Value.ToString
  else if Control is TPresentedTextControl then
    TPresentedTextControl(Control).Text := Value.ToString
  else if Control is TLabel then
    TLabel(Control).Text := Value.ToString
  else
    raise Exception.Create('TTextAdapter: controle não suportado: ' + Control.ClassName);
end;

{ TBoolAdapter }
function TBoolAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TCheckBox then
    Exit(TCheckBox(Control).IsChecked);

  if Control is TRadioButton then
    Exit(TRadioButton(Control).IsChecked);

  raise Exception.Create('TBoolAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TBoolAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
begin
  if Control is TCheckBox then
    TCheckBox(Control).IsChecked := Value.AsBoolean
  else if Control is TRadioButton then
    TRadioButton(Control).IsChecked := Value.AsBoolean
  else
    raise Exception.Create('TBoolAdapter: controle não suportado: ' + Control.ClassName);
end;

{ TListIndexAdapter }
function TListIndexAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TComboBox then
    Exit(TComboBox(Control).ItemIndex);

  if Control is TListBox then
    Exit(TListBox(Control).ItemIndex);

  raise Exception.Create('TListIndexAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TListIndexAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
begin
  if Control is TComboBox then
    TComboBox(Control).ItemIndex := Value.AsInteger
  else if Control is TListBox then
    TListBox(Control).ItemIndex := Value.AsInteger
  else
    raise Exception.Create('TListIndexAdapter: controle não suportado: ' + Control.ClassName);
end;

{ TTrackBarAdapter }
function TTrackBarAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TTrackBar then
    Exit(TTrackBar(Control).Value);

  raise Exception.Create('TTrackBarAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TTrackBarAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
begin
  if Control is TTrackBar then
    TTrackBar(Control).Value := Value.AsExtended
  else
    raise Exception.Create('TTrackBarAdapter: controle não suportado: ' + Control.ClassName);
end;

{ TDateTimeAdapter }
function TDateTimeAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TDateEdit then
    Exit(TDateEdit(Control).Date);

  if Control is TTimeEdit then
    Exit(TTimeEdit(Control).Time);

  raise Exception.Create('TDateTimeAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TDateTimeAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
var
  dt: TDateTime;
begin
  if Value.IsEmpty then Exit;
  if Value.TryAsType<TDateTime>(dt) then
  begin
    if Control is TDateEdit then
      TDateEdit(Control).Date := dt
    else if Control is TTimeEdit then
      TTimeEdit(Control).Time := dt;
    Exit;
  end;

  try
    dt := StrToDateTime(Value.ToString);
    if Control is TDateEdit then
      TDateEdit(Control).Date := dt
    else if Control is TTimeEdit then
      TTimeEdit(Control).Time := dt;
  except
    // ignore
  end;
end;

{ TLabelAdapter }
function TLabelAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  // label não atualiza objeto
  Result := TValue.Empty;
end;

procedure TLabelAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
begin
  if Control is TLabel then
    TLabel(Control).Text := Value.ToString;
end;

{ TImageAdapter }
function TImageAdapter.StringIsBase64(const S: string): Boolean;
var
  t: string;
begin
  t := S.Trim;
  Result := (t <> '') and (Pos(' ', t) = 0) and ((Length(t) mod 4) = 0) and
            ((Pos('=', t) > 0) or (Pos('/', t) > 0) or (Pos('+', t) > 0));
end;

function TImageAdapter.BitmapFromBase64(const S: string): TBitmap;
var
  bytes: TBytes;
  ms: TMemoryStream;
  bmp: TBitmap;
begin
  bmp := nil;
  Result := nil;
  try
    bytes := TNetEncoding.Base64.DecodeStringToBytes(S);
    ms := TMemoryStream.Create;
    try
      if Length(bytes) > 0 then
        ms.WriteBuffer(bytes[0], Length(bytes));
      ms.Position := 0;
      bmp := TBitmap.CreateFromStream(ms);
      Result := bmp;
    finally
      ms.Free;
    end;
  except
    FreeAndNil(bmp);
    raise;
  end;
end;

function TImageAdapter.ControlToValue(Control: TFmxObject): TValue;
begin
  if Control is TImage then
  begin
    if TImage(Control).Bitmap <> nil then
      Result := TValue.From<TBitmap>(TImage(Control).Bitmap)
    else
      Result := TValue.Empty;
  end
  else
    raise Exception.Create('TImageAdapter: controle não suportado: ' + Control.ClassName);
end;

procedure TImageAdapter.ValueToControl(Control: TFmxObject; const Value: TValue);
var
  bmp: TBitmap;
  s: string;
  filename: string;
begin
  if not (Control is TImage) then
    raise Exception.Create('TImageAdapter: controle não suportado: ' + Control.ClassName);

  // TBitmap direto
  if Value.IsObject and (Value.AsObject is TBitmap) then
  begin
    TImage(Control).Bitmap.Assign(TBitmap(Value.AsObject));
    Exit;
  end;

  // string: pode ser filename ou base64
  s := Value.ToString;
  if s = '' then
  begin
    TImage(Control).Bitmap := nil;
    Exit;
  end;

  // arquivo
  if TFile.Exists(s) then
  begin
    bmp := TBitmap.Create;
    try
      bmp.LoadFromFile(s);
      TImage(Control).Bitmap := bmp;
    finally
      bmp.Free;
    end;
    Exit;
  end;

  // base64
  if StringIsBase64(s) then
  begin
    bmp := BitmapFromBase64(s);
    try
      if Assigned(bmp) then
        TImage(Control).Bitmap := bmp;
    finally
      bmp.Free;
    end;
    Exit;
  end;

  // fallback: tenta caminho absoluto
  filename := TPath.GetFullPath(s);
  if TFile.Exists(filename) then
  begin
    bmp := TBitmap.Create;
    try
      bmp.LoadFromFile(filename);
      TImage(Control).Bitmap := bmp;
    finally
      bmp.Free;
    end;
    Exit;
  end;

  // se não encontrou, limpa
  TImage(Control).Bitmap := nil;
end;

{ TListTextAdapter }

function TListTextAdapter.ControlToValue(Control: TFmxObject): TValue;
var
  Lb: TListBox;
  Cb: TComboBox;
begin
  if Control is TListBox then
  begin
    Lb := TListBox(Control);
    if (Lb.ItemIndex >= 0) and (Lb.ItemIndex < Lb.Count) then
      Exit(Lb.ListItems[Lb.ItemIndex].Text)
    else
      Exit('');
  end;

  if Control is TComboBox then
  begin
    Cb := TComboBox(Control);
    if (Cb.ItemIndex >= 0) and (Cb.ItemIndex < Cb.Items.Count) then
      Exit(Cb.Items[Cb.ItemIndex])
    else
      Exit('');
  end;

  Result := TValue.Empty;
end;

procedure TListTextAdapter.ValueToControl(Control: TFmxObject;
  const Value: TValue);
var
  Lb: TListBox;
  Cb: TComboBox;
  i: Integer;
  S: string;
begin
  if not Value.IsType<string> then Exit;
  S := Value.AsType<string>;

  if Control is TListBox then
  begin
    Lb := TListBox(Control);
    for i := 0 to Lb.Count - 1 do
      if SameText(Lb.ListItems[i].Text, S) then
      begin
        Lb.ItemIndex := i;
        Exit;
      end;
    Exit;
  end;

  if Control is TComboBox then
  begin
    Cb := TComboBox(Control);
    for i := 0 to Cb.Items.Count - 1 do
      if SameText(Cb.Items[i], S) then
      begin
        Cb.ItemIndex := i;
        Exit;
      end;
  end;
end;

end.
