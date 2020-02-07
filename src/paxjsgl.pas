unit paxjsgl;
{$mode objfpc}{$H+}
{$D+}
interface

uses
  Classes, SysUtils, typinfo, paxjs, fgl, fpjson;

type
  { TGenericListTypeHandle }

  generic TGenericListTypeHandle <aType: TFPSList; aItemType: TObject> = class(TJsonTypeHandler)
  private
    type
     TCastContainerType = aType;
     TCastContainedType = aItemType;
  protected
    procedure parseType(aObject: aType; arrayNode: TJSONArray);
    procedure stringifyType(AObject: TCastContainerType; out Res: TJSONData);
  public
    constructor Create;
    destructor Destroy; override;
    function parse(const AObject: TObject; Info: PPropInfo; const node: TJSONData): boolean; override;
    function stringify(AObject: TObject; Info: PPropInfo; out Res: TJSONData): boolean; override;
  end;

  { TGenericInterfaceListTypeHandle }
  TInterfaceFactory =class
    function createInstance : IInterface; virtual; abstract;
    function getInstance(item : IInterface) : TObject;virtual; abstract;
  end;

  generic TGenericInterfaceListTypeHandle <aType: TFPSList; aItemType;providedFactoryType: TInterfaceFactory> = class(TJsonTypeHandler)
  private
    type
     TCastContainerType = aType;
    var
      FFactory :providedFactoryType;
  protected
    procedure parseType(aObject: aType; arrayNode: TJSONArray);
    procedure stringifyType(AObject: TCastContainerType; out Res: TJSONData);
  public
    constructor Create;
    destructor Destroy; override;
    function parse(const AObject: TObject; Info: PPropInfo; const node: TJSONData): boolean; override;
    function stringify(AObject: TObject; Info: PPropInfo; out Res: TJSONData): boolean; override;
  end;


implementation


{ TGenericInterfaceListTypeHandle }

procedure TGenericInterfaceListTypeHandle.parseType(aObject: aType;  arrayNode: TJSONArray);
var
  idx: integer;
  handlers: THandlerList;
  outInterface : IInterface;
  h: TJsonTypeHandler;
  childNode: TJSONData;
  obj : TObject;
  item : aItemType absolute outInterface;
begin
  if arrayNode.isNull then exit;
  getHandlers(tkClass, handlers);
  for idx := 0 to arrayNode.Count - 1 do
  begin
    childNode := arrayNode[idx];
    outInterface := ffactory.createInstance;
    for h in handlers do
    begin
      try
        obj:=  ffactory.getInstance(item);
        if h.parse(obj, nil, childNode) then
        begin
          aObject.Add({$ifdef darwin} @item{$else}item{$endif} );
          break;
        end;
      except
      end;
    end;

  end;
  handlers.Free;
end;

procedure TGenericInterfaceListTypeHandle.stringifyType(  AObject: TCastContainerType; out Res: TJSONData);
var
  idx: integer;
  item: TObject;
  childNode: TJSONData;
  handlers: THandlerList;
  h: TJSONTypeHandler;
begin
  if AObject = nil then
  begin
    res := CreateJSON;
  end
  else
  begin
    doLog(etDebug,AObject.ClassName);
    Res := TJSONArray.Create;
    getHandlers(tkClass, handlers);
    for idx := 0 to TFPSList(aObject).count - 1 do
    begin
      for h in handlers do
      begin
        if h.stringify(ffactory.getInstance(IInterface(aObject[idx])), nil, childNode) then
          break;
      end;
      if childNode <> nil then
        TJSONArray(res).Add(childNode);
    end;
    handlers.Free;
  end;
end;

constructor TGenericInterfaceListTypeHandle.Create;
begin
  ffactory := providedFactoryType.Create;
end;

destructor TGenericInterfaceListTypeHandle.Destroy;
begin
  FreeAndNil(ffactory);
  inherited Destroy;
end;

function TGenericInterfaceListTypeHandle.parse(const AObject: TObject;
  Info: PPropInfo; const node: TJSONData): boolean;
var
  aList: aType;
begin
  result := False;
  if (Info = nil) and  (compareText(AObject.ClassName,TCastContainerType.className)=0) then
  begin
    parseType(TCastContainerType(AObject), node as TJSONArray);
    result := True;
  end
  else
  begin
    if (Info <> nil) and (compareText(AObject.ClassName,TCastContainerType.className)=0) and (Info^.PropType^.Kind in [tkClass, tkObject]) then
    begin
      aList := TCastContainerType(GetObjectProp(AObject, Info));
      parseType(aList, node as TJSONArray);
      result := True;
    end;
  end;
end;

function TGenericInterfaceListTypeHandle.stringify(AObject: TObject;  Info: PPropInfo; out Res: TJSONData): boolean;
var
  aList: aType;
begin
  result := False;
  if (CompareText(AObject.ClassName, TCastContainerType.ClassName)=0) then
  begin
    doLog(etDebug,AObject.ClassName);
    if (Info = nil) then
    begin
      stringifyType(TCastContainerType(AObject), res);
      result := True;
    end
    else
    if (Info <> nil) then
    begin
      aList := TCastContainerType(GetObjectProp(AObject, Info));
      stringifyType(aList, Res);
      result := True;
    end;
  end;
end;

{ TGenericListTypeHandle }

procedure TGenericListTypeHandle.parseType(aObject: aType; arrayNode: TJSONArray);
var
  idx: integer;
  item: TCastContainedType;
  handlers: THandlerList;
  h: TJsonTypeHandler;
  factory: TFactory;
  childNode: TJSONData;
begin
  getHandlers(tkClass, handlers);
  factory := GetJSONFactory(TCastContainedType);

  for idx := 0 to arrayNode.Count - 1 do
  begin
    childNode := arrayNode[idx];
    if childNode.IsNull then continue;
    item := factory(TCastContainedType) as TCastContainedType;
    try
      for h in handlers do
      begin
        if h.parse(item, nil, childNode) then
        begin
          aObject.Add(
          {$ifdef Darwin}@item{$else}item{$endif}
          );
          break;
        end;
      end;
    except
      on e: Exception do
        raise Exception.CreateFmt('on parse [%d], error %s', [idx, e.Message]);
    end;
  end;
  handlers.Free;
end;

procedure TGenericListTypeHandle.stringifyType(AObject: TCastContainerType; out  Res: TJSONData);
var
  idx: integer;
  item: TObject;
  childNode: TJSONData;
  handlers: THandlerList;
  h: TJSONTypeHandler;
begin
  if AObject = nil then
  begin
    res := CreateJSON;
  end else
  begin
    Res := TJSONArray.Create;
    for idx := 0 to TFPSList(aObject).count - 1 do
    begin
      getHandlers(tkClass, handlers);
      item := TCastContainedType(aObject[idx]);
      for h in handlers do
      begin
        if h.stringify(item, nil, childNode) then break;
      end;
      if childNode <> nil then TJSONArray(res).Add(childNode);
      handlers.Free;
    end;
  end;
end;

constructor TGenericListTypeHandle.Create;
begin
end;

destructor TGenericListTypeHandle.Destroy;
begin
  inherited Destroy;
end;

function TGenericListTypeHandle.parse(const AObject: TObject; Info: PPropInfo;
  const node: TJSONData): boolean;
var
  aList: aType;
  aClassName : String;
begin
  result := False;
  aClassName:= AObject.ClassName;
  doLog(etDebug, Format('parse check %s :: %s',[AObject.ClassName, TCastContainerType.ClassName]));

  if (Info = nil) and  (compareText(aClassName,TCastContainerType.className)=0) then
  begin
    parseType(TCastContainerType(AObject), node as TJSONArray);
    result := True;
  end
  else
  begin
    if (Info <> nil) and (compareText(aClassName,TCastContainerType.className)=0) and (Info^.PropType^.Kind in [tkClass, tkObject]) then
    begin
      aList := TCastContainerType(GetObjectProp(AObject, Info));
      parseType(aList, node as TJSONArray);
      result := True;
    end;
  end;
end;

function TGenericListTypeHandle.stringify(AObject: TObject; Info: PPropInfo; out Res: TJSONData): boolean;
var
  aList: aType;
begin
  result := False;
  doLog(etDebug, Format('%s.stringify check %s :: %s',[self.classname, AObject.ClassName,TCastContainerType.ClassName]));
  if (CompareText(AObject.ClassName, TCastContainerType.ClassName)=0) then
  begin
    if (Info = nil) then
    begin
      stringifyType(TCastContainerType(AObject), res);
      result := True;
    end
    else
    if (Info <> nil) then
    begin
      aList := TCastContainerType(GetObjectProp(AObject, Info));
      stringifyType(aList, Res);
      result := True;
    end;
  end;
end;

end.



