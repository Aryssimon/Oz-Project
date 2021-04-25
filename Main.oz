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

      fun {GetRecord Database Record}
         local BrowseQuestions in
            fun {BrowseQuestions ArityCharacter Record}
               case ArityCharacter
               of nil then Record
               [] H|T then
                  % Add the question to the record and set the value to 0
                  {BrowseQuestions T {AdjoinAt Record H 0}}
               end
            end
            case Database
            of nil then Record
            [] H|T then
               % Call BrowseQuestions with each character
               {GetRecord T {BrowseQuestions {Arity H}.2 Record}}
            end
         end
      end

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

      fun {GetTrueResponders L Database Question}
         case Database
         of nil then L
         [] H|T then
            if {HasFeature H Question} == false orelse H.Question == true then
               {GetTrueResponders {Append L [{Record.subtract H Question}]} T Question}
            else
               {GetTrueResponders L T Question}
            end
         end
      end

      fun {GetFalseResponders L Database Question}
         case Database
         of nil then L
         [] H|T then
            if {HasFeature H Question} == false orelse H.Question == false then
               {GetFalseResponders {Append L [{Record.subtract H Question}]} T Question}
            else
               {GetFalseResponders L T Question}
            end
         end
      end

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
               if {CheckOneQuestion Responders H 'wait'} == false then
                  false
               else
                  {HaveSameAnswers Responders T}
               end
            end
         end
      end

      fun {GetOnlyNames Database Names}
         case Database
         of nil then Names
         [] H|T then {GetOnlyNames T H.1|Names}
         end
      end

      fun {RemoveQuestion Database Q Result}
         case Database
         of nil then Result
         [] H|T then {RemoveQuestion T Q {Record.subtract H Q}}
         end
      end

      fun {TreeBuilder Database}
         local R Q EmptyR TrueResponders FalseResponders UnknownDatabase in
            EmptyR = {GetRecord Database '|'()} % Create the record with question as key and 0 as value
            if {Length Database} == 1 orelse {HaveSameAnswers Database {Arity EmptyR}} then
               leaf({GetOnlyNames Database nil})
            else
               R = {FeedRecord EmptyR Database} % Get and store the Difference True-False for each question in the record
               Q = {GetMinQuestion R} % Get the question with the lowest (true-false) ratio
               TrueResponders = {GetTrueResponders nil Database Q}
               FalseResponders = {GetFalseResponders nil Database Q}
               UnknownDatabase = {RemoveQuestion Database Q Database}


               question(Q true:{TreeBuilder TrueResponders} false:{TreeBuilder FalseResponders} 'unknown':{TreeBuilder UnknownDatabase})
            end
         end
      end

      fun {GameDriver Tree}
         case Tree
         of leaf(Result) then
            local Res in
               Res = {ProjectLib.found Result}
               if Res == false then
                  {Print 'Je me suis trompé\n'}
                  {Print {ProjectLib.surrender}}
               else
                  {WriteListToFile Result OutputFile}
               end
               unit
            end
         [] question(1:Q false:T1 true:T2 'unknown':T3) then
            if {ProjectLib.askQuestion Q} == true then
               {GameDriver T2}
            else
               {GameDriver T1}
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
