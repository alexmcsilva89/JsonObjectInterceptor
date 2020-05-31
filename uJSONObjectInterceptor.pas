unit uJSONObjectInterceptor;

interface
uses
  System.JSON,System.DateUtils, System.SysUtils, System.Rtti, System.Character, System.JSONConsts,
  System.Generics.Collections,REST.Json.Types, REST.Json,Rest.JsonReflect;


  type TJSONObjectInterceptor = class
  private
    class procedure Interceptor(JsonFields: TJsonObject; Obj: TClass);
    class procedure InterceptorFields(JsonFields: TJsonObject; Obj: TClass );
    class procedure ProcessOptions(AJsonObject: TJSONObject; AOptions: TJsonOptions); static;
    class function JsonToObject<T: class, constructor>(AJsonObject: TJSONObject; AOptions: TJsonOptions = [joDateIsUTC, joDateFormatISO8601]): T; overload;
  public
    const cnstStrValorStrEmpty = 'emptystring';
    const cnstStrValorStrNull  = 'nullstring';
    const cnstIntFloatValorNull = -2147483648;
    class function JsonToObject<T: class, constructor>(const AJson: string; AOptions: TJsonOptions = [joDateIsUTC, joDateFormatISO8601]): T; overload;
  end;

implementation

uses
  System.Variants, System.Classes, System.TypInfo;

{ TJSONObjectInterceptor }
class function TJSONObjectInterceptor.JsonToObject<T>(const AJson: string; AOptions: TJsonOptions = [joDateIsUTC, joDateFormatISO8601]): T;
var
  LJson: string;
  LJSONValue: TJSONValue;
  LJSONObject: TJSONObject;
  Obj: TObject;
begin
  LJSONValue := TJSONObject.ParseJSONValue(AJson);
  LJSONObject := nil;
  try
    if Assigned(LJSONValue) and (LJSONValue is TJSONObject) then
      LJSONObject := LJSONValue as TJSONObject
    else
    begin
      LJson := AJson.Trim;
      if (LJson = '') and not Assigned(LJSONValue) or
         (LJson <> '') and Assigned(LJSONValue) and LJSONValue.Null then
        Exit(nil)
      else
        raise EConversionError.Create(SCannotCreateObject);
    end;

    Interceptor(LJSONObject,T);

    Result := JsonToObject<T>(LJSONObject, AOptions);
  finally
    LJSONValue.Free;
  end;
end;

class procedure TJSONObjectInterceptor.ProcessOptions(AJsonObject: TJSONObject;
  AOptions: TJsonOptions);
var
  LPair: TJSONPair;
  LItem: TObject;
  i: Integer;

  function IsEmpty(ASet: TJsonOptions): Boolean;
  var
    LElement: TJsonOption;
  begin
    Result := True;
    for LElement in ASet do
    begin
      Result := False;
      break;
    end;
  end;

begin
  if Assigned(AJsonObject) and not IsEmpty(AOptions) then

    for i := AJsonObject.Count - 1 downto 0 do
    begin
      LPair := TJSONPair(AJsonObject.Pairs[i]);
      if LPair.JsonValue is TJSONObject then
        ProcessOptions(TJSONObject(LPair.JsonValue), AOptions)
      else if LPair.JsonValue is TJSONArray then
      begin
        if (joIgnoreEmptyArrays in AOptions) and (TJSONArray(LPair.JsonValue).Count = 0) then
          AJsonObject.RemovePair(LPair.JsonString.Value).DisposeOf
        else
          for LItem in TJSONArray(LPair.JsonValue) do
            if LItem is TJSONObject then
              ProcessOptions(TJSONObject(LItem), AOptions)
      end
      else
        if (joIgnoreEmptyStrings in AOptions) and (LPair.JsonValue.value = '') then
          AJsonObject.RemovePair(LPair.JsonString.Value).DisposeOf;
    end;
end;

class procedure TJSONObjectInterceptor.Interceptor(JsonFields: TJsonObject; Obj: TClass);
begin
  InterceptorFields(JsonFields,Obj);
end;

class procedure TJSONObjectInterceptor.InterceptorFields(JsonFields: TJsonObject; Obj: TClass );
var
  jsonPairField: TJSONPair;
  jsonFieldVal: TJSONValue;
  jsonArray: TJsonArray;
  jsonObj: TJsonObject;
  FieldName: String;
  I: Integer;
  ctx : TRTTIContext;
  typeRtti: TRttiType;
  propertyRtti: TRttiProperty;
  className:String;
  classT: TClass;
  fieldRtti: TRttiField;
  lClass: TClass;
  jsonString: string;
  strValue: string;


  procedure ValidatePair(aJsonPair: TJSONPair; aJsonObj: TJsonObject; aObj: TCLass);

    procedure ValidateFields;
    begin
      if (propertyRtti <> nil) then
        begin
           case propertyRtti.PropertyType.TypeKind of
              tkEnumeration:;

              tkWChar, tkChar,tkLString,
              tkUString,tkShortString,tkWString:
              begin
                if jsonFieldVal.Value = 'true' then
                begin
                  aJsonObj.RemovePair(FieldName).DisposeOf;
                  aJsonObj.AddPair(FieldName,'S');
                end
                else if jsonFieldVal.Value = 'false' then
                begin
                  aJsonObj.RemovePair(FieldName).DisposeOf;
                  aJsonObj.AddPair(FieldName,'N');
                end
                else
                if jsonFieldVal.Value = 'null' then
                begin
                  aJsonObj.RemovePair(FieldName).DisposeOf;
                  aJsonObj.AddPair(FieldName,cnstStrValorStrNull);
                end
                else if jsonFieldVal.Value = emptystr then
                begin
                  aJsonObj.RemovePair(FieldName).DisposeOf;
                  aJsonObj.AddPair(FieldName,cnstStrValorStrEmpty);
                end;
              end;

              tkInteger,tkFloat:
              begin
                if JsonFieldVal.ToString = 'null' then
                begin
                  aJsonObj.RemovePair(FieldName).DisposeOf;
                  aJsonObj.AddPair(FieldName,TJsonNumber.Create(cnstIntFloatValorNull));
                end;
              end;

              tkClass:
              begin
                fieldRtti := typeRtti.GetField('F'+FieldName);
                lClass := fieldRtti.FieldType.AsInstance.MetaclassType;
                InterceptorFields(aJsonObj,lClass);
              end;
           end;
        end;
    end;

  var
    strValue: String;
    J,K,L: Integer;
    unitname, nameclass: string;
    valor,fieldRttiName,propertyName: string;
    lJsonPair: TJSONPair;
    lJsonArray : TJSONArray;
    lJsonObj: TJSONObject;
    lTypeRtti: TRttitype;
    lfieldRtti: TRttiField;
  begin
    ctx := TRTTIContext.Create;

    try
      FieldName := aJsonPair.JsonString.Value;
      jsonFieldVal := aJsonPair.JsonValue;
      strValue := jsonFieldVal.Value;
      className := aObj.QualifiedClassName;
      typeRtti :=  Ctx.FindType(className);
      propertyRtti := typeRtti.GetProperty(FieldName);
      if propertyRtti <> nil then
      begin
        fieldRtti := typeRtti.GetField('F'+propertyRtti.Name);
        if (fieldRtti.FieldType is TRttiDynamicArrayType) then
        begin
          typeRtti := TRttiDynamicArrayType(fieldRtti.FieldType).ElementType;
          if (aJsonPair.JsonValue is TJSONArray) then
          begin
            jsonArray := aJsonPair.JsonValue as TJSONArray;
            for J := jsonArray.Count -1 downto 0 do
            begin
              if  jsonArray.Items[J] is TJSONValue then
              begin
                jsonObj := JsonArray.Remove(J) as TJSONObject;
                for K := jsonObj.Count - 1 downto 0 do
                begin
                  FieldName := jsonObj.Pairs[K].JsonString.Value;
                  jsonFieldVal := jsonObj.Pairs[K].JsonValue;
                  jsonString := aJsonObj.ToString;
                  valor := aJsonObj.ToString;
                  propertyRtti := typeRtti.GetProperty(FieldName);
                  if (propertyRtti <> nil) then
                  begin
                    nameclass := propertyRtti.PropertyType.Name;
                    unitname := typeRtti.AsInstance.DeclaringUnitName;
                    propertyName := propertyRtti.Name;
                    fieldRttiName := fieldRtti.Name;
                    case propertyRtti.PropertyType.TypeKind of
                       tkEnumeration:;

                       tkWChar, tkChar,tkLString,
                       tkUString,tkShortString,tkWString:
                       begin
                         if jsonFieldVal.Value = 'true' then
                         begin
                           jsonObj.RemovePair(FieldName).DisposeOf;
                           jsonObj.AddPair(FieldName,'S');
                         end
                         else if jsonFieldVal.Value = 'false' then
                         begin
                           jsonObj.RemovePair(FieldName).DisposeOf;
                           jsonObj.AddPair(FieldName,'N');
                         end
                         else
                         if jsonFieldVal.Value = 'null' then
                         begin
                           jsonObj.RemovePair(FieldName).DisposeOf;
                           jsonObj.AddPair(FieldName,cnstStrValorStrNull);
                         end

                         else if jsonFieldVal.Value = emptystr then
                         begin
                           jsonObj.RemovePair(FieldName).DisposeOf;
                           jsonObj.AddPair(FieldName,cnstStrValorStrEmpty);
                         end;
                       end;

                       tkInteger,tkFloat:
                       begin
                         if JsonFieldVal.ToString = 'null' then
                         begin
                           jsonObj.RemovePair(FieldName).DisposeOf;
                           jsonObj.AddPair(FieldName,TJSONNumber.Create(cnstIntFloatValorNull));
                         end;
                       end;

                       tkClass:
                       begin
                         fieldRtti := typeRtti.GetField('F'+FieldName);
                         lClass := fieldRtti.FieldType.AsInstance.MetaclassType;
                         InterceptorFields(TJSONObject(jsonObj.Pairs[K].JsonValue),lClass);
                       end;

                       tkDynArray:
                       begin
                         lfieldRtti := typeRtti.GetField('F'+FieldName);
                         ltypeRtti := TRttiDynamicArrayType(lfieldRtti.FieldType).ElementType;
                         lclass := ltypeRtti.AsInstance.MetaclassType;
                         if (lfieldRtti.FieldType is TRttiDynamicArrayType) then
                         begin
                           lJsonPair := jsonObj.Pairs[K];
                           if lJsonPair.JsonValue is TJSONArray then
                           begin
                             lJsonArray := lJsonPair.JsonValue as TJSONArray;
                             for L := lJsonArray.Count -1 downto 0 do
                             begin
                               ljsonObj := lJsonArray.Remove(L) as TJSONObject;
                               InterceptorFields(ljsonObj,lClass);
                               lJsonArray.AddElement(ljsonObj);
                             end;
                             strValue := jsonObj.Pairs[K].ToString;
                           end
                           else if lJsonPair.JsonValue is TJSONObject then
                           begin
                             aJsonObj.RemovePair(FieldName).DisposeOf;
                             aJsonObj.AddPair(FieldName,TJSONArray.Create);
                           end;
                         end;
                       end;
                    end;
                  end;
                end;
                jsonArray.AddElement(jsonObj);
              end;
            end;
          end
          else if (aJsonPair.JsonValue is TJSONObject) then
          begin
            aJsonObj.RemovePair(FieldName).DisposeOf;
            aJsonObj.AddPair(FieldName,TJSONArray.Create);
          end;
        end
        else
         ValidateFields;
      end;
    finally
      ctx.Free;
    end;
  end;

begin
  for I := JsonFields.Count -1 downto 0 do
  begin
    JsonPairField := TJSONPair(JsonFields.Pairs[I]);
    if JsonPairField.JsonValue is TJSONObject then
    begin
      ctx := TRTTIContext.Create;
      FieldName := JsonPairField.JsonString.Value;
      jsonFieldVal := JsonPairField.JsonValue;
      className := obj.QualifiedClassName;
      typeRtti :=  Ctx.FindType(className);
      propertyRtti := typeRtti.GetProperty(FieldName);
      ctx.Free;
      if propertyRtti <> nil then
      begin
        fieldRtti := typeRtti.GetField('F'+propertyRtti.Name);
        if (fieldRtti.FieldType is TRttiDynamicArrayType) then
        begin
          if jsonPairField.JsonValue is TJSONObject then
          begin
            jsonFields.RemovePair(FieldName).DisposeOf;
            jsonFields.AddPair(FieldName,TJSONArray.Create);
            typeRtti := TRttiDynamicArrayType(fieldRtti.FieldType).ElementType;
            propertyRtti := typeRtti.GetProperty(FieldName);
            if propertyRtti <> nil then
            begin
              fieldRtti := typeRtti.GetField('F'+propertyRtti.Name);
              classT := fieldRtti.FieldType.AsInstance.MetaclassType;
              InterceptorFields(TJsonObject(JsonPairField.JsonValue),classT);
            end;
          end;
        end
        else
        begin
          classT := fieldRtti.FieldType.AsInstance.MetaclassType;
          InterceptorFields(TJsonObject(JsonPairField.JsonValue),classT);
        end
      end;
    end
    else
      ValidatePair(JsonPairField,JsonFields,Obj);
  end;
  strValue := JsonFields.ToString;
end;
class function TJSONObjectInterceptor.JsonToObject<T>(AJsonObject: TJSONObject;AOptions: TJsonOptions): T;
var
  LUnMarshaler: TJSONUnMarshal;
begin
  if AJsonObject = nil then
    Exit(nil);

  LUnMarshaler := TJSONUnMarshal.Create;
  try
    LUnMarshaler.DateTimeIsUTC  := joDateIsUTC in AOptions;
    if joDateFormatUnix in AOptions then
      LUnMarshaler.DateFormat :=jdfUnix
    else if joDateFormatISO8601 in AOptions then
      LUnMarshaler.DateFormat := jdfISO8601
    else if joDateFormatMongo in AOptions then
      LUnMarshaler.DateFormat := jdfMongo
    else if joDateFormatParse in AOptions then
      LUnMarshaler.DateFormat := jdfParse;

    ProcessOptions(AJSONObject, AOptions);

    Result := LUnMarshaler.CreateObject(T, AJsonObject) as T;
  finally
    LUnMarshaler.Free;
  end;
end;

end.
