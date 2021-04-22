ListOfCharacters = {ProjectLib.loadDatabase file 'database.txt'}

declare
Database = [
character('Harry Potter'
'Est-ce que c\'est une fille ?':false
'A-t-il des cheveux noirs ?':true
'Porte-t-il des lunettes ?':true
'A-t-il des cheveux roux ?':false
)
character('Ron Weasley'
'Est-ce que c\'est une fille ?':false
'A-t-il des cheveux noirs ?':false
'Porte-t-il des lunettes ?':false
'A-t-il des cheveux roux ?':true
)
character('Hermione Granger'
'Est-ce que c\'est une fille ?':true
'A-t-il des cheveux noirs ?':false
'Porte-t-il des lunettes ?':false
'A-t-il des cheveux roux ?':false
)
character('Ginny Weasley'
'Est-ce que c\'est une fille ?':true
'A-t-il des cheveux noirs ?':false
'Porte-t-il des lunettes ?':false
'A-t-il des cheveux roux ?':true
)
character('Minerva McGonagall'
'Est-ce que c\'est une fille ?':true
'A-t-il des cheveux noirs ?':false
'Porte-t-il des lunettes ?':true
'A-t-il des cheveux roux ?':false
)
character('Severus Rogue'
'Est-ce que c\'est une fille ?':false
'A-t-il des cheveux noirs ?':true
'Porte-t-il des lunettes ?':false
'A-t-il des cheveux roux ?':false
)
]


declare
fun {GetRecord ArityCharacter Record}
  case ArityCharacter
  of nil then Record
  [] H|T then
    % Add the question to the record and set the value to 0
    {GetRecord T {AdjoinAt Record H 0}}
  end
end


declare
fun {FeedRecord R Database}
  local CountTrueFalse in
    fun {CountTrueFalse Character ArityCharacter Record}
      case ArityCharacter
      of nil then Record
      [] H|T then
        if Character.H == true then
          % Add 1 to the value of the record if true
          {CountTrueFalse Character T {AdjoinAt Record H (Record.H + 1)}}
        elseif Character.H == false then
          % Sub 1 to the value of the record if false
          {CountTrueFalse Character T {AdjoinAt Record H (Record.H - 1)}}
        end
      end
    end
    case Database
    of nil then R
    [] H|T then
      {FeedRecord {CountTrueFalse H {Arity H}.2 R} T}
    end
  end
end


declare
fun {GetMinQuestion R}
  local RecFinder A in
    fun {RecFinder R ArityR MinValue MinQuestion}
      case ArityR
      of nil then MinQuestion
      [] H|T then
        if {Abs R.H} < MinValue then
          {RecFinder R T {Abs R.H} H}
        else
          {RecFinder R T MinValue MinQuestion}
        end
      end
    end
    A = {Arity R}
    {RecFinder R A {Abs R.(A.1)} A.1}
  end
end


declare
fun {GetTrueResponders L Database Question}
  case Database
  of nil then L
  [] H|T then
    if H.Question == true then
      {GetTrueResponders {Append L [{Record.subtract H Question}]} T Question}
    else
      {GetTrueResponders L T Question}
    end
  end
end


declare
fun {GetFalseResponders L Database Question}
  case Database
  of nil then L
  [] H|T then
    if H.Question == false then
      {GetFalseResponders {Append L [{Record.subtract H Question}]} T Question}
    else
      {GetFalseResponders L T Question}
    end
  end
end


declare
fun {HaveSameAnswers Responders Questions}
  local CheckOneQuestion in
    fun {CheckOneQuestion Responders First Question}
      case Responders
      of nil then true
      [] H|T then
        if H.Question \= First.Question then
          false
        else
          {CheckOneQuestion T First Question}
        end
      end
    end
    case Questions
    of nil then true
    [] H|T then
      if {CheckOneQuestion Responders Responders.1 H} == false then
        false
      else
        {HaveSameAnswers Responders T}
      end
    end
  end
end


declare
fun {GetOnlyNames Database Names}
  case Database
  of nil then Names
  [] H|T then {GetOnlyNames T H.1|Names}
  end
end


declare
fun {TreeBuilder Database}
  if {Length Database} == 1 orelse {HaveSameAnswers Database {Arity Database.1}.2} then
    leaf({GetOnlyNames Database nil})
  else
    local R Q EmptyR TrueResponders FalseResponders in
      EmptyR = {GetRecord {Arity Database.1}.2 '|'()} % Create the record with question as key and 0 as value
      R = {FeedRecord EmptyR Database} % Get and store the Difference True-False for each question in the record
      Q = {GetMinQuestion R} % Get the question with the lowest (true-false) ratio
      TrueResponders = {GetTrueResponders nil Database Q}
      FalseResponders = {GetFalseResponders nil Database Q}

      question(Q true:{TreeBuilder TrueResponders} false:{TreeBuilder FalseResponders})
    end
  end
end

declare
Tree = {TreeBuilder Database}
{Browse Tree}