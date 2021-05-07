functor
import
   ProjectLib
   Browser
   OS
   System
   Application
   Open
define
   CWD = {Atom.toString {OS.getCWD}}#"/"
   Browse = proc {$ Buf} {Browser.browse Buf} end
   Print = proc{$ S} {System.print S} end
   Args = {Application.getArgs record('nogui'(single type:bool default:false optional:true)
									  'db'(single type:string default:CWD#"database.txt")
                    'ans'(single type:string default:CWD#"test_answers.txt"))}
in
   local
	   NoGUI = Args.'nogui'
	   DB = Args.'db'
      ListOfCharacters = {ProjectLib.loadDatabase file Args.'db'}
      ListOfAnswersFile = ListOfAnswersFile = Args.'ans'
      ListOfAnswers = {ProjectLib.loadCharacter file ListOfAnswersFile}

      OutputFile = {New Open.file init(name: stdout
          flags: [write create truncate text])}

      /**
       * Recursively write the result (L) to the OutputFile (F).
       */
      proc {WriteListToFile L F}
      % F must be an opened file.
         case L
         of H|nil then
            {F write(vs:H)}
         []H|T then
            {F write(vs:H#",")}
            {WriteListToFile T F}
         end
      end

      /**
       * Add each question as keys in the record with a counter set to 0.
       * e.g. : Record(Q1:0 Q2:0 ...).
       */
      fun {GetRecord Questions Record}
         case Questions
         of nil then Record
         [] H|T then
         % Add the question to the record and set the value to 0.
            {GetRecord T {AdjoinAt Record H 0}}
         end
      end


      /**
       * Visits each character, and loop over each question,
       * if the answer is True then add 1 in the record where the question is the key,
       * if the answer is False then subtract 1.
       *
       * Returns a record with the questions as keys and a number (trues - falses) as value.
       */
      fun {FeedRecord Record Database}
         local CountTrueFalse in
            fun {CountTrueFalse Character Questions Record}
               case Questions
               of nil then Record
               [] H|T then
                  if Character.H == true then
                     % Add 1 to the value of the record if true.
                     {CountTrueFalse Character T {AdjoinAt Record H (Record.H + 1)}}
                  elseif Character.H == false then
                     % Sub 1 to the value of the record if false.
                     {CountTrueFalse Character T {AdjoinAt Record H (Record.H - 1)}}
                  end
               end
            end
            case Database
            of nil then Record
            [] H|T then
               % Call CountTrueFalse with each character
               if {Width {Arity H}} > 1 then % Check if character has at least one question
                  {FeedRecord {CountTrueFalse H {Arity H}.2 Record} T}
               else
                  {FeedRecord Record T}
               end
            end
         end
      end

      /**
       * Return the question in record "Record" with minimum abs(true-false).
       * e.g. : Record(Q1:-1 Q2:-2 Q3:2) will return Q1.
       */
      fun {GetMinQuestion Record}
         local RecFinder A in
            %function to get the question with minimum abs(value).
            fun {RecFinder Record Questions MinValue MinQuestion}
               case Questions
               of nil then MinQuestion
               [] H|T then
                  if {Abs Record.H} < MinValue then
                     {RecFinder Record T {Abs Record.H} H}
                  else
                     {RecFinder Record T MinValue MinQuestion}
                  end
               end
            end
            A = {Arity Record}
            {RecFinder Record A {Abs Record.(A.1)} A.1}
         end
      end


      /**
       * Returns the list of characters whose answer is True for the question in parameters.
       */
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

      /**
       * Returns the list of characters in Database whose answer is False for the question in parameters.
       */
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


      /**
       * Returns True if the characters in "Responders" have the same answers
       * for the questions in "Questions", otherwise returns False.
       */
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

      /**
       * Return Names : a list of the character's names in Database.
       */
      fun {GetOnlyNames Database Names}
         case Database
         of nil then Names
         [] H|T then {GetOnlyNames T H.1|Names}
         end
      end

      /**
       * Recursively build a Tree from the Database.
       */
      fun {TreeBuilder Database}
         if {Length Database} == 1 orelse {HaveSameAnswers Database {Arity Database.1}.2} then
            leaf({GetOnlyNames Database nil})
         else
            local R Q EmptyR TrueResponders FalseResponders in
               EmptyR = {GetRecord {Arity Database.1}.2 '|'()} % Create the record with question as key and 0 as value.
               R = {FeedRecord EmptyR Database} % Get and store the Difference True-False for each question in the record.
               Q = {GetMinQuestion R} % Get the question with the lowest (true-false) ratio.
               TrueResponders = {GetTrueResponders nil Database Q} % Get characters whose answer to the question is True.
               FalseResponders = {GetFalseResponders nil Database Q} % Get characters whose answer to the question is False.

               question(Q true:{TreeBuilder TrueResponders} false:{TreeBuilder FalseResponders})
            end
         end
      end

      /**
       * Recursively ask the questions from the decision tree to the player based on his answers.
       */
      fun {GameDriver Tree}
         case Tree
         % End of Tree
         of leaf(Result) then
            local Res in
               Res = {ProjectLib.found Result}
               if Res == false then
                  {Print 'Je me suis trompé\n'}
                  {Print {ProjectLib.surrender}}
               else
                  {WriteListToFile Result OutputFile} % Write the solution to stdout.
               end
               unit
            end
         % Goes to false Tree or true Tree based on answer
         [] question(1:Q false:T1 true:T2) then
            if {ProjectLib.askQuestion Q} then
               {GameDriver T2}
            else
               {GameDriver T1}
            end
         end
      end
   in
    {ProjectLib.play opts(characters:ListOfCharacters driver:GameDriver
                            noGUI:NoGUI builder:TreeBuilder
                            autoPlay:ListOfAnswers)}

    {OutputFile close}
    {Application.exit 0}
   end
end
