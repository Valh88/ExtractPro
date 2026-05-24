unit AuthTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

const
  AUTH_SERVER_DEFAULT_PORT = 8081;
  AUTH_SESSION_EXPIRE_HOURS = 24;
  AUTH_TOKEN_SIZE = 32;

type
  TAuthResponse = record
    Success: Boolean;
    SessionToken: string;
    UserId: Int64;
    Login: string;
    ErrorMsg: string;
  end;

  TAuthResult = record
    Valid: Boolean;
    UserId: Int64;
    Login: string;
  end;

  IAuthValidator = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}']
    function ValidateToken(const Token: string): TAuthResult;
  end;

implementation

end.