ListOfCharacters = {ProjectLib.loadDatabase file 'database.txt'}


declare
fun {GetRecord Character}
  local Record in
    for V in {Arity Character} do
      if Character.V == true then
        {AdjoinAt Record Character.V 0} % Add the question to the record and set the value to 0
      elseif Character.V == false then
        {AdjoinAt Record Character.V 0} % Do the same when false (this avoid the name of the character)
      end
    end
    Record
  end
end


declare
fun {FeedRecord R Database}
  for Character in Database do
    for V in {Arity Character} do
      if Character.V == true then
        {AdjoinAt R Character.V (R.Character.V + 1)} % Add 1 to the value of the record if true
      elseif Character.V == false then
        {AdjoinAt R Character.V (R.Character.V - 1)} % Sub 1 to the value of the record if false
      end
    end
  end
  R
end

declare
fun {GetMinQuestion R}
  local MinValue MinQuestion in
    MinValue = Max
    for V in {Arity R} do
      if {Abs R.V} < MinValue then
        MinValue = {Abs R.V}
        MinQuestion = R.V
      end
    end
    MinQuestion
  end
end


declare
fun {GetTrueResponders Database Question}
  local L in
    L = []
    for Character in Database do
      if Character.Question == true then
        Character = {Subtract Character Question}
        L = {Append L Character}
      end
    end
    L
  end
end


declare
fun {GetFalseResponders Database Question}
  local L in
    L = []
    for Character in Database do
      if Character.Question == false then
        Character = {Subtract Character Question}
        L = {Append L Character}
      end
    end
    L
  end
end


declare
fun {HaveSameAnswers Responders}
  for Question in {Arity Responders.1} do
    local V in
      V = Responders.1.Question
      for Character in Responders do
        if Character.Question == Not V then
          false
        end
      end
    end
  end
  true
end

declare
fun {TreeBuilder Database}
  if {Width Database == 1} orelse {HaveSameAnswers Database} then
    leaf(Database)
  else
    local R Q in
      R = {GetRecord Database.1} % Create the record with question as key and 0 as value
      R = {FeedRecord R Database} % Get and store the Difference True-False for each question in the record
      Q = {GetMinQuestion R} % Get the question with the lowest (true-false) ratio
      TrueResponders = {GetTrueResponders Database Q}
      FalseResponders = {GetFalseResponders Database Q}

      question(Q true:{TreeBuilder TrueResponders} false:{TreeBuilder FalseResponders})
    end
  end
end


{Browse {TreeBuilder ListOfCharacters}}
