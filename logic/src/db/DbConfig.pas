unit DbConfig;

{$mode objfpc}{$H+}

interface

uses
  mormot.core.base,
  mormot.orm.base,
  mormot.orm.core;

type
  TOrmServerConfig = class(TOrm)
  private
    fKey: RawUtf8;
    fValue: RawUtf8;
  published
    property Key: RawUtf8 read fKey write fKey stored AS_UNIQUE;
    property Value: RawUtf8 read fValue write fValue;
  end;

implementation

end.
