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
      %NewCharacter = {ProjectLib.loadCharacter file CWD#"new_character.txt"}

      ListOfAnswersFile = Args.'ans'
      ListOfAnswers = {ProjectLib.loadCharacter file ListOfAnswersFile}

      OutputFile = {New Open.file init(name: stdout
          flags: [write create truncate text])}


      /**
       * Recursively write the result (L) to the OutputFile (F).
       */
      proc {WriteListToFile L F}
      % F must be an opened file
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
      fun {GetRecord Database Record}
         local BrowseQuestions in
            fun {BrowseQuestions CharacterQuestions Record}
               % Loop over each Question for a character
               case CharacterQuestions
               of nil then Record
               [] H|T then
                  % Add the question to the record and set the value to 0 if not in the Record already
                  {BrowseQuestions T {AdjoinAt Record H 0}}
               end
            end
            % Loop over each character in Database
            case Database
            of nil then Record
            [] H|T then
               % Call BrowseQuestions with each character
               if {Width {Arity H}} > 1 then % Check if character has at least one question
                  {GetRecord T {BrowseQuestions {Arity H}.2 Record}}
               else
                  {GetRecord T Record}
               end
            end
         end
      end


      /**
       * Visits each character, and loop over each question,
       * if the answer is True then add 1 in the record where the question is the key,
       * if the answer is False then subtract 1.
       *
       * Returns a record with the questions as keys and a number (trues - falses) as value.
       */
      fun {FeedRecord R Database}
         local CountTrueFalse in
            fun {CountTrueFalse Character CharacterQuestions Record}
               % Loop over each Question for a character
               case CharacterQuestions
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
              % Call CountTrueFalse with each character
               if {Width {Arity H}} > 1 then % Check if character has at least one question
                  {FeedRecord {CountTrueFalse H {Arity H}.2 R} T}
               else
                  {FeedRecord R T}
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
            fun {RecFinder Record ArityR MinValue MinQuestion}
               case ArityR
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
            if {HasFeature H Question} == false orelse H.Question == true then  % If the character doesn't have the question, consider his answer true
               {GetTrueResponders {Append L [{Record.subtract H Question}]} T Question}
            else
               {GetTrueResponders L T Question}
            end
         end
      end


      /**
       * Returns the list of characters whose answer is False for the question in parameters.
       */
      fun {GetFalseResponders L Database Question}
         case Database
         of nil then L
         [] H|T then
            if {HasFeature H Question} == false orelse H.Question == false then % If the character doesn't have the question, consider his answer false
               {GetFalseResponders {Append L [{Record.subtract H Question}]} T Question}
            else
               {GetFalseResponders L T Question}
            end
         end
      end


      /**
       * Function used when the player answers 'unknown', we then keep all characters and remove the Question.
       * Return a list L with all the characters from Database without Question.
       */
      fun {GetUnknownResponders L Database Question}
         case Database
         of nil then L
         [] H|T then
            {GetUnknownResponders {Append L [{Record.subtract H Question}]} T Question}
         end
      end

      /**
       * For each question, each character must have the same answers or not having
       * answer to this question for the function to continue.
       *
       *  - If an answer is different from a character to another then returns False.
       *  - If all questions have been asked and no difference in the answers have
       * been found then returns True.
       */
      fun {HaveSameAnswers Responders Questions}
         local CheckOneQuestion in
            fun {CheckOneQuestion Responders Question Value}
               case Responders
               of nil then true
               [] H|T then
                  if {HasFeature H Question} then
                     if Value == 'wait' then
                        {CheckOneQuestion T Question H.Question} % Set value
                     elseif H.Question \= Value then
                        false
                     else
                        {CheckOneQuestion T Question Value}
                     end
                  else
                     {CheckOneQuestion T Question Value}
                  end
               end
            end
            case Questions
            of nil then true
            [] H|T then
               % wait is a temporary value that'll be replaced by the answer of
               % the first character having this question.
               if {CheckOneQuestion Responders H 'wait'} == false then
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
         local R Q EmptyR TrueResponders FalseResponders UnknownResponders in
            EmptyR = {GetRecord Database '|'()} % Create the record with question as key and 0 as value
            if {Length Database} == 1 orelse {HaveSameAnswers Database {Arity EmptyR}} then
               leaf({GetOnlyNames Database nil})
            else
               R = {FeedRecord EmptyR Database} % Get and store the Difference True-False for each question in the record
               Q = {GetMinQuestion R} % Get the question with the lowest (true-false) ratio
               TrueResponders = {GetTrueResponders nil Database Q} % Get characters whose answer to the question is True.
               FalseResponders = {GetFalseResponders nil Database Q} % Get characters whose answer to the question is False.
               % Get all characters and remove question Q. (Useful when player chooses unknown when answering to this question)
               UnknownResponders = {GetUnknownResponders nil Database Q}


               question(Q true:{TreeBuilder TrueResponders} false:{TreeBuilder FalseResponders} 'unknown':{TreeBuilder UnknownResponders})
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
         % Goes to one of the 3 branchs based on the answer.
         [] question(1:Q false:T1 true:T2 'unknown':T3) then
            local Answer in
               Answer = {ProjectLib.askQuestion Q}
               if Answer == false then
                  {GameDriver T1}
               elseif Answer == true then
                  {GameDriver T2}
               else
                  {GameDriver T3}
               end
            end
         end
      end
   in
    {ProjectLib.play opts(characters:ListOfCharacters driver:GameDriver
                            noGUI:NoGUI builder:TreeBuilder
                            autoPlay:ListOfAnswers
                            allowUnknown:true)}
    {OutputFile close}
    {Application.exit 0}
   end
end
